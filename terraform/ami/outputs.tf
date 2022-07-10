output "ec2_ip" {
  value = aws_instance.nixos.public_ip
}
