output "aws_security_group_details" {
  value = aws_security_group.Jenkins_server_sg
}

output "Jenkins_server_public_dns" {
  value = aws_instance.Jenkins_server.public_dns
}