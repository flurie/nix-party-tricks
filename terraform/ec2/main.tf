### Data sources ###

data "aws_ami" "nixos-latest" {
  most_recent = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["080433136561"] # NixOS Foundation
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
  name        = "nixos"
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
  ami                    = data.aws_ami.nixos-latest.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.aws_ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.nixos.id]

  root_block_device {
    # need this to be big enough to build things
    volume_size = 20
  }

  tags = {
    Name = "nix-party-tricks"
  }

  user_data = <<END
### https://nixos.org/channels/nixos-22.05 nixos

{ config, pkgs, modulesPath, ... }: {
  # nix uses same string interpolation as terraform, so we must escape it here
  imports = [ "$${modulesPath}/virtualisation/amazon-image.nix" ];
  ec2.hvm = true;
  system.stateVersion = "22.05";
  networking.hostName = "nixos-aws";
  environment.systemPackages = with pkgs; [ nix-direnv direnv git ];
  nix = {
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      experimental-features = nix-command flakes
    '';
    settings = {
      substituters = [ "https://flurie.cachix.org" ];
      trusted-public-keys =
        [ "flurie.cachix.org-1:A80LCk3Y3l9gkYSdSJvXYV6q/Dh41Tx8nG1yO1j9T5A=" ];
    };
  };

  programs.bash.interactiveShellInit = ''
    eval "$($${pkgs.direnv}/bin/direnv hook bash)"
  '';
}
END
}
