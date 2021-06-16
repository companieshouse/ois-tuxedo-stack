data "aws_vpc" "heritage" {
  filter {
    name   = "tag:Name"
    values = ["vpc-heritage-${var.environment}"]
  }
}

data "aws_subnet_ids" "application" {
  vpc_id = data.aws_vpc.heritage.id

  filter {
    name   = "tag:Name"
    values = [var.application_subnet_pattern]
  }
}

data "aws_subnet" "application" {
  count = length(data.aws_subnet_ids.application.ids)
  id    = tolist(data.aws_subnet_ids.application.ids)[count.index]
}

data "aws_ami" "ois_tuxedo" {
  owners      = [var.ami_owner_id]
  most_recent = true
  name_regex  = "^${var.service_subtype}-ami-\\d.\\d.\\d"

  filter {
    name   = "name"
    values = ["${var.service_subtype}-ami-${var.ami_version_pattern}"]
  }
}

resource "aws_placement_group" "ois" {
  name     = local.common_resource_name
  strategy = "spread"
}

resource "aws_key_pair" "master" {
  key_name   = "${local.common_resource_name}-master"
  public_key = var.ssh_master_public_key
}

resource "aws_security_group" "common" {
  name   = "common-${local.common_resource_name}"
  vpc_id = data.aws_vpc.heritage.id

  ingress {
    description = "Allow SSH connectivity for application deployments"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.deployment_cidrs
  }

  dynamic "ingress" {
    for_each = var.tuxedo_services
    iterator = service
    content {
      description = "Allow health check requests from network load balancer to Tuxedo ${upper(service.key)} services"
      from_port   = service.value
      to_port     = service.value
      protocol    = "TCP"
      cidr_blocks = formatlist("%s/32", [for eni in data.aws_network_interface.nlb : eni.private_ip])
    }
  }

  dynamic "ingress" {
    for_each = var.tuxedo_services
    iterator = service
    content {
      description = "Allow connectivity connectivity for Tuxedo ${upper(service.key)} services"
      from_port   = service.value
      to_port     = service.value
      protocol    = "TCP"
      cidr_blocks = [var.chips_cidr]
    }
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags ,{
    Name = "common-${local.common_resource_name}"
  })
}

resource "aws_instance" "ois" {
  count = var.instance_count

  ami             = data.aws_ami.ois_tuxedo.id
  instance_type   = var.instance_type
  key_name        = aws_key_pair.master.id
  placement_group = aws_placement_group.ois.id
  subnet_id       = element(local.application_subnet_ids_by_az, count.index) # use 'element' function for wrap-around behaviour

  iam_instance_profile   = module.instance_profile.aws_iam_instance_profile.name
  user_data_base64       = data.template_cloudinit_config.config[count.index].rendered
  vpc_security_group_ids = [aws_security_group.common.id]

  dynamic "ebs_block_device" {
    for_each = [
      for block_device in data.aws_ami.ois_tuxedo.block_device_mappings :
        block_device if block_device.device_name != data.aws_ami.ois_tuxedo.root_device_name
    ]
    iterator = block_device
    content {
      device_name = block_device.value.device_name
      encrypted   = block_device.value.ebs.encrypted
      iops        = block_device.value.ebs.iops
      snapshot_id = block_device.value.ebs.snapshot_id
      volume_size = var.lvm_block_devices[index(var.lvm_block_devices.*.lvm_physical_volume_device_node, block_device.value.device_name)].aws_volume_size_gb
      volume_type = block_device.value.ebs.volume_type
    }
  }

  root_block_device {
    volume_size = var.root_volume_size
  }

  tags = merge(local.common_tags ,{
    Name = "${var.service_subtype}-${var.service}-${var.environment}-${count.index + 1}"
  })
  volume_tags = local.common_tags
}
