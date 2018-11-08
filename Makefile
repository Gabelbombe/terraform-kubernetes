ROLE          ?= GEHC-037     ## make {func} ROLE=<AWS_ACCOUNT_ROLE>
REGION        ?= us-east-1    ## make {func} REGION=<AWS_TARGET_REGION>
CIDR          ?= '0.0.0.0/0'  ## make {func} CIDR=<inbound traffic block for maintenance>


###############################################
# Global Variables
# - Setup and templating variables
###############################################

SHELL         := /bin/bash
CHDIR_SHELL   := $(SHELL)
OS            := darwin

BASE_DIR      := $(shell pwd)
ACCOUNT_ID    := $(shell aws sts --profile $(ROLE) get-caller-identity --output text --query 'Account')
INVENTORY     := $(shell which terraform-inventory |awk '{print$3}')

STATE_DIR     := $(BASE_DIR)/_states/$(ACCOUNT_ID)
LOGS_DIR      := $(BASE_DIR)/_logs/$(ACCOUNT_ID)
KEYS_DIR      := $(BASE_DIR)/_keys

MODULE        := $(BASE_DIR)/modules/kubernetes
ANSIBLE       := $(BASE_DIR)/ansible

SIGNATURE     := $(shell ssh-keygen -y -f $(KEYS_DIR)/$(ROLE))

## Default generics to test until I move it over to Rake
default: test
all:     terraform provision
rebuild: destroy all


###############################################
# Helper functions
# - follows best practices design patterns
###############################################
define chdir
	$(eval _D=$(firstword $(1) $(@D)))
	$(info $(MAKE): cd $(_D)) $(eval SHELL = cd $(_D); $(CHDIR_SHELL))
endef

.preflight:
	@mkdir -p $(STATE_DIR)
	@mkdir -p $(LOGS_DIR)
	@mkdir -p $(KEYS_DIR)

.check-region:
	@if test "$(REGION)" = ""; then  echo "REGION not set"; exit 1; fi

.check-role:
		@if test "$(ROLE)" = ""; then  echo "ROLE not set"; exit 1; fi

.directory-%:
	$(call chdir, ${${*}})

.assert-%:
	@if [ "${${*}}" = "" ]; then                                                  \
    echo "[✗] Variable ${*} not set"  ; exit 1                                ; \
	else                                                                          \
		echo "[√] ${*} set as: ${${*}}"                                           ; \
	fi

.roles: .directory-ANSIBLE
	sed -e "s/<SSH_KEYFILE>/$(ROLE)/" ansible.tmpl.cfg >| ansible.cfg


###############################################
# Generic functions
###############################################
graph: .directory-MODULE
	terraform init && terraform graph |dot -Tpng >| $(LOGS_DIR)/graph.png

clean:
	@rm -rf $(TERRAFORM)/.terraform
	@rm -f  $(LOGS_DIR)/graph.png
	@rm -f  $(LOGS_DIR)/*.log

globals:
	@echo "REGION set to: $(REGION)"
	@echo "ROLE   set to: $(ROLE)"

###############################################
# Testing functions
# - follow testing design patterns
###############################################

test:
	@echo 'No tests currently configured...'


###############################################
# Deployment functions
# - follows standard design patterns
###############################################

init: .preflight .directory-MODULE
	terraform init

terraform: init .directory-MODULE .check-region
	aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform plan                \
		-var region=$(REGION)                                                       \
		-var key_name=$(ROLE)                                                       \
	2>&1 |tee $(LOGS_DIR)/kubernetes-plan.log                                   ; \
                                                                                \
	aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform apply               \
		-state=$(STATE_DIR)/$(ROLE)_$(REGION)_terraform.tfstate                     \
		-var default_keypair_public_key="$(SIGNATURE)"                              \
		-var default_keypair_name=$(ROLE)                                           \
		-var control_cidr="0.0.0.0/0"                                               \
		-var region=$(REGION)                                                       \
		-auto-approve                                                               \
	2>&1 |tee $(LOGS_DIR)/kubernetes-apply.log



provision: .roles infra kubectl

infra: .directory-ANSIBLE
	export TF_STATE=$(STATE_DIR)/$(ROLE)_$(REGION)_terraform.tfstate            ; \
	echo -e "\n\n\n\ninfra.yml: $(date +"%Y-%m-%d @ %H:%M:%S")\n"                 \
		>> $(LOGS_DIR)/ansible-infra-provision.log                                ; \
	ansible-playbook -v infra.yml                                                 \
		--extra-vars "ec2_private_dns_name=`terraform output -state=$$TF_STATE |head -1 |awk -F' = ' '{print$$2}'`" \
		--inventory-file=$(INVENTORY)                                               \
	2>&1 |tee $(LOGS_DIR)/ansible-infra-provision.log

kubectl: .directory-ANSIBLE
	export TF_STATE=$(STATE_DIR)/$(ROLE)_$(REGION)_terraform.tfstate            ; \
	echo -e "\n\n\n\kubectl.yml: $(date +"%Y-%m-%d @ %H:%M:%S")\n"                \
		>> $(LOGS_DIR)/ansible-kubectl-provision.log                              ; \
	ansible-playbook -v kubectl.yml                                               \
		--extra-vars "kubernetes_api_endpoint=`terraform output -state=$$TF_STATE |head -1 |awk -F' = ' '{print$$2}'`" \
		--inventory-file=$(INVENTORY)                                               \
	2>&1 |tee $(LOGS_DIR)/ansible-kubectl-provision.log


destroy: init .directory-MODULE .check-region
	@echo -e "\n\n\n\nkubernetes-destroy: $(date +"%Y-%m-%d @ %H:%M:%S")\n"       \
		>> $(LOGS_DIR)/kubernetes-destroy.log
	aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform destroy             \
		-state=$(STATE_DIR)/$(ROLE)_$(REGION)_terraform.tfstate                     \
		-var default_keypair_public_key="$(SIGNATURE)"                              \
		-var default_keypair_name=$(ROLE)                                           \
		-var control_cidr="0.0.0.0/0"                                               \
		-var region=$(REGION)                                                       \
		-auto-approve                                                               \
	2>&1 |tee $(LOGS_DIR)/kubernetes-destroy.log


ssh: .directory-MODULE
	exec `terraform output -state=$(STATE_DIR)/$(ROLE)_$(REGION)_terraform.tfstate \
	|head -1 |awk -F' = ' '{print$$2}' |sed 's/.\//..\//'`


purge: destroy clean
	@rm -f $(STATE_DIR)/$(ACCOUNT_ID)$(ROLE)_$(REGION)_terraform.tfstate
	@rm -f $(KEYS_DIR)/*$(ACCOUNT_ID)-${REGION}*
