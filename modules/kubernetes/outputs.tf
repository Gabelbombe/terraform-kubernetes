############
## Outputs
############

output "kubernetes_api_dns_name" {
  value = "${aws_elb.kubernetes_api.dns_name}"
}

output "kubernetes_workers_public_ip" {
  value = "${join(",", aws_instance.worker.*.public_ip)}"
}

output "kubernetes_etcd_private_dns" {
  value = "${join(",", aws_instance.etcd.*.private_dns)}"
}
