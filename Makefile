ROLE          ?= GEHC-037    ## make {func} ROLE=<AWS_ACCOUNT_ROLE>
REGION        ?= us-east-1   ## make {func} REGION=<AWS_TARGET_REGION>



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
all:     terraform
rebuild: destroy



###############################################
# Helper functions
# - follows standard design patterns
###############################################
define chdir
    $(eval _D=$(firstword $(1) $(@D)))
    $(info $(MAKE): cd $(_D)) $(eval SHELL = cd $(_D); $(CHDIR_SHELL))
endef

.check-region:
    @if test "$(REGION)" = ""; then echo "REGION not set"; exit 1; fi

.directory-%:
    $(call chdir, ${${*}})

.assert-%:
    @if [ "${${*}}" = "" ]; then                                                  \
    echo "[✗] Variable ${*} not set"  ; exit 1                                ; \
    else                                                                          \
        echo "[√] ${*} set as: ${${*}}"                                           ; \
    fi



###############################################
# Generic functions
# - follows standard design patterns
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
    @echo "[info] Testing Terraform"
    @if ! terraform fmt -write=false -check=true >> /dev/null; then               \
        echo "[✗] Terraform fmt failed: $$d"                                      ; \
        exit 1                                                                    ; \
    else                                                                          \
        echo "[√] Terraform fmt"                                                  ; \
    fi
    @for d in $$(find . -type f -name '*.tf' -path "./targets/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
        cd $$d                                                                    ; \
        terraform init -backend=false >> /dev/null                                ; \
        terraform validate -check-variables=false                                 ; \
        if [ $$? -eq 1 ]; then                                                      \
            echo "[✗] Terraform validate failed: $$d"                               ; \
            exit 1                                                                  ; \
        fi                                                                        ; \
    done
    @echo "[√] terraform validate targets (not including variables)"
    @for d in $$(find . -type f -name '*.tf' -path "./examples/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
        cd $$d                                 ; \
        terraform init -backend=false >> /dev/null;                                 \
        terraform validate;                                                         \
        if [ $$? -eq 1 ]; then                                                      \
            echo "[✗] Terraform validate failed: $$d";                                \
            exit 1;                                                                   \
        fi;                                                                         \
    done
    @echo "[√] Terraform validate examples"

.PHONY: default test



###############################################
# Deployment functions
# - follows standard design patterns
###############################################

terraform: .directory-MODULE .check-region
    mkdir -p $(LOGS_DIR) && terraform init .                                  ; \
    aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform plan              \
			-var default_keypair_public_key="$(SIGNATURE)" \
			-var default_keypair_name="$(ROLE)" \
    2>&1 |tee $(LOGS_DIR)/plan.log                                            ; \
                                                                                \
    aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform apply               \
        -state=$(STATE_DIR)/$(ROLE)_terraform.tfstate                               \
				-var default_keypair_public_key="$(SIGNATURE)" \
				-var default_keypair_name="$(ROLE)" \
        -auto-approve                                                               \
    2>&1 |tee $(LOGS_DIR)/apply.log

destroy: .directory-MODULE .check-region
    mkdir -p $(LOGS_DIR) && terraform init .                                    ; \
    aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform destroy             \
        -state=$(STATE_DIR)/$(ROLE)_terraform.tfstate                               \
				-var default_keypair_public_key="$(SIGNATURE)" \
				-var default_keypair_name="$(ROLE)" \
        -auto-approve                                                               \
    2>&1 |tee $(LOGS_DIR)/destroy.log


purge: destroy clean
    @rm -f $(STATE_DIR)/$(ACCOUNT_ID)/${REGION}-rds.tfstate
    @rm -f $(KEYS_DIR)/*$(ACCOUNT_ID)-${REGION}*
