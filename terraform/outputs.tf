output "ec2_public_ip" {
  description = "Elastic IP of the EC2 instance"
  value       = aws_eip.sms_eip.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.sms_server.id
}

output "app_url" {
  description = "Student Management API URL"
  value       = "http://${aws_eip.sms_eip.public_ip}:5000"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_eip.sms_eip.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_eip.sms_eip.public_ip}:9090"
}
