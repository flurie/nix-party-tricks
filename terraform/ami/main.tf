resource "aws_s3_bucket" "nixos-ami" {
  bucket = "flurie-nixos-ami"
  acl    = "private"

  tags = {
    Name = "NixOS AMI Images"
  }
}

resource "aws_iam_role" "vmimport" {
  name               = "vmimport"
  assume_role_policy = file("./templates/vmie-trust-policy.json")
}

resource "aws_iam_role_policy" "vmimport_policy" {
  name   = "vmimport"
  role   = aws_iam_role.vmimport.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "${aws_s3_bucket.nixos-ami.arn}",
        "${aws_s3_bucket.nixos-ami.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetBucketAcl"
      ],
      "Resource": [
        "${aws_s3_bucket.nixos-ami.arn}",
        "${aws_s3_bucket.nixos-ami.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:ModifySnapshotAttribute",
        "ec2:CopySnapshot",
        "ec2:RegisterImage",
        "ec2:Describe*"
      ],
      "Resource": "*"
    }
  ]
    }
EOF
}

resource "aws_s3_bucket_object" "nixos_22_05" {
  bucket = aws_s3_bucket.nixos-ami.bucket
  key    = "nixos-22.05-nginx.vhd"

  source = "./result/nixos-amazon-image-22.11.20220702.660ac43-x86_64-linux.vhd"
  etag   = filemd5("./result/nixos-amazon-image-22.11.20220702.660ac43-x86_64-linux.vhd")
}

resource "aws_ebs_snapshot_import" "nixos_22_05" {
  disk_container {
    format = "VHD"
    user_bucket {
      s3_bucket = aws_s3_bucket.nixos-ami.bucket
      s3_key    = aws_s3_bucket_object.nixos_22_05.key
    }
  }

  role_name = aws_iam_role.vmimport.name

  tags = {
    Name = "NixOS-22.05"
  }
}

resource "aws_ami" "nixos_22_05" {
  name                = "nixos_22_05"
  architecture        = "x86_64"
  virtualization_type = "hvm"
  root_device_name    = "/dev/xvda"
  ena_support         = true
  sriov_net_support   = "simple"

  ebs_block_device {
    device_name           = "/dev/xvda"
    snapshot_id           = aws_ebs_snapshot_import.nixos_22_05.id
    volume_size           = 20
    delete_on_termination = true
    volume_type           = "gp3"
  }
}

data "http" "my-ipv4" {
  url = "https://ipv4.icanhazip.com/"
}

# NOTE: I count this because this is an "advanced" resource,
# i.e., terraform only "manages" this for the sake of state.
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

### Secondary resources ###

## SSH ##

resource "tls_private_key" "aws_ssh_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "aws_ssh_key" {
  key_name   = "generated-key-${sha256(tls_private_key.aws_ssh_key.public_key_openssh)}"
  public_key = tls_private_key.aws_ssh_key.public_key_openssh
}

resource "local_file" "aws_ssh_key" {
  # abs path means we can use the same path in flake without impurity
  filename        = "/tmp/nixos-ssh.pem"
  content         = tls_private_key.aws_ssh_key.private_key_openssh
  file_permission = "0600"
}

### Primary AWS resources ###

resource "aws_security_group" "nixos" {
  name        = "nixos-ami"
  description = "Basic setup for nixos aws demo"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "ssh from current IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my-ipv4.response_body)}/32"]
  }

  ingress {
    description = "http from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "full egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "nixos"
  }
}

resource "aws_instance" "nixos" {
  ami                    = aws_ami.nixos_22_05.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.nixos.id]
  key_name               = aws_key_pair.aws_ssh_key.key_name

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "nix-party-tricks-ami"
  }
}
