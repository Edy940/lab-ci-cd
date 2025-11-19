output "nlb_dns_name" {
  value = format("http://%s", data.aws_lb.this.dns_name)
}