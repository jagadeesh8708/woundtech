provider "aws" {
  region = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_ecs_cluster" "aws-ecs" {
  name = var.app_name
}

data "aws_ami" "ecs-ami" {
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.*"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  owners = ["amazon"]
}

variable "aws_ecs_ami_image" {
  default = ""
  description = "Machine image to use for ec2 instances"
}

locals {
  aws_ecs_ami = var.aws_ecs_ami_image == "" ? data.aws_ami.ecs-ami.id : var.aws_ecs_ami_image
}

resource "aws_iam_role" "ecs-cluster-machine-role" {
  name = "${var.app_name}-cluster-runner-role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs-cluster-machine-policy" {
  statement {
    actions = ["ec2:Describe*", "ecr:Describe*", "ecr:BatchGet*"]
    resources = ["*"]
  }
  statement {
    actions = ["ecs:*"]
    resources = ["arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.app_name}/*"]
  }
}

resource "aws_iam_role_policy" "ecs-cluster-machine-role-policy" {
  name = "${var.app_name}-cluster-runner-policy"
  role = aws_iam_role.ecs-cluster-machine-role.name
  policy = data.aws_iam_policy_document.ecs-cluster-machine-policy.json
}

resource "aws_iam_instance_profile" "ecs-cluster-machine-profile" {
  name = "${var.app_name}-cluster-runner-iam-profile"
  role = aws_iam_role.ecs-cluster-machine-role.name
}

data "template_file" "cluster_user_data" {
  template = "${file("${path.module}/templates/cluster_user_data.sh")}"
  vars = { 
    ecs_cluster = aws_ecs_cluster.aws-ecs.name
  }
}

resource "aws_instance" "ecs-cluster-machine" {
  ami = local.aws_ecs_ami
  instance_type = var.instance_type
  subnet_id = element(aws_subnet.aws-subnet.*.id, 0)
  vpc_security_group_ids = [aws_security_group.ecs-cluster-host.id]
  associate_public_ip_address = true
  key_name = var.aws_key_pair_name
  user_data = data.template_file.cluster_user_data.rendered
  count = var.ec2_machine_count
  iam_instance_profile = aws_iam_instance_profile.ecs-cluster-machine-profile.name

  tags = {
    Name = "${var.app_name}-ecs-cluster-machine"
    Environment = var.app_environment
    Role = "ecs-cluster"
  }
  volume_tags = {
    Name = "${var.app_name}-ecs-cluster-machine"
    Environment = var.app_environment
    Role = "ecs-cluster"
  }
}

resource "aws_security_group" "ecs-cluster-host" {
  name = "${var.app_name}-ecs-cluster-host"
  description = "${var.app_name}-ecs-cluster-host"
  vpc_id = aws_vpc.aws-vpc.id
  
  tags = {
    Name = "${var.app_name}-ecs-cluster-host"
    Environment = var.app_environment
    Role = "ecs-cluster"
  }
}

resource "aws_security_group_rule" "ecs-cluster-host-ssh" {
  security_group_id = aws_security_group.ecs-cluster-host.id
  description = "host SSH access to ecs cluster"
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = var.host_sources_cidr
}

resource "aws_security_group_rule" "egress-cluster" {
  security_group_id = aws_security_group.ecs-cluster-host.id
  description = "egress for ecs cluster"
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

output "ecs_cluster_machine_ip" {
  description = "External IP for ECS Cluster"
  value = [aws_instance.ecs-cluster-machine.*.public_ip]
}
