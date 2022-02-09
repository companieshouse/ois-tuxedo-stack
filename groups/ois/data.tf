data "aws_caller_identity" "current" {}

data "aws_iam_policy" "qsp_transfer_vpc_access" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "qsp_transfer_execution" {
  dynamic "statement" {
    for_each = var.qsp_transfer_enabled ? [1] : []

    content {
      sid = "AllowLambdaLoggingToCloudWatchLogGroup"

      effect = "Allow"

      actions = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]

      resources = ["${aws_cloudwatch_log_group.qsp_transfer[0].arn}:*"]
    }
  }

  dynamic "statement" {
    for_each = var.qsp_transfer_enabled ? [1] : []

    content {
      sid = "AllowLambdaReadAccessToQSPLogEvents"

      effect = "Allow"

      actions = [
        "logs:FilterLogEvents"
      ]

      resources = ["${aws_cloudwatch_log_group.tuxedo[var.qsp_transfer_log_group_name].arn}:*"]
    }
  }

  dynamic "statement" {
    for_each = var.qsp_transfer_enabled ? [1] : []

    content {
      sid = "AllowLambdaToReadSecretData"

      effect = "Allow"

      actions = [
        "secretsmanager:GetSecretValue"
      ]

      resources = [aws_secretsmanager_secret_version.qsp_transfer.arn]
    }
  }

  dynamic "statement" {
    for_each = var.qsp_transfer_enabled ? [1] : []

    content {
      sid = "AllowLambdaToDecryptSecretDataWithThisKey"

      effect = "Allow"

      actions = [
        "kms:Decrypt"
      ]

      resources = [aws_kms_key.ois.arn]
    }
  }
}

data "aws_iam_policy_document" "qsp_transfer_trust" {
  statement {
    sid = "LambdaCanAssumeThisRole"

    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

data "aws_route53_zone" "ois" {
  name     = local.dns_zone
  vpc_id   = data.aws_vpc.heritage.id
}

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
  name_regex  = "^${var.service_subtype}-${var.service}-ami-\\d.\\d.\\d"

  filter {
    name   = "name"
    values = ["${var.service_subtype}-${var.service}-ami-${var.ami_version_pattern}"]
  }
}

data "aws_iam_roles" "sso_administrator" {
  name_regex  = "AWSReservedSSO_AdministratorAccess.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/${var.region}"
}

data "aws_iam_user" "concourse" {
    user_name = "concourse-platform"
}

data "aws_iam_policy_document" "ois" {
  statement {
    sid = "EnableIAMPolicies"
    
    principals {
      type        = "AWS"
      identifiers =["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "AllowAccessForKeyAdministrators"

    principals {
      type        = "AWS"
      identifiers = local.kms_key_administrator_arns
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

data "cloudinit_config" "config" {
  count = var.instance_count

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init/templates/system-config.yml.tpl", {})
  }

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init/templates/bootstrap-commands.yml.tpl", {
      instance_hostname = "${var.service_subtype}-${var.service}-${var.environment}-${count.index + 1}"
      lvm_block_devices = var.lvm_block_devices
    })
  }
}


data "vault_generic_secret" "kms_keys" {
  path = "aws-accounts/${var.aws_account}/kms"
}

data "vault_generic_secret" "security_s3_buckets" {
  path = "aws-accounts/security/s3"
}

data "vault_generic_secret" "security_kms_keys" {
  path = "aws-accounts/security/kms"
}

data "vault_generic_secret" "qsp_transfer" {
  count = local.qsp_transfer_count

  path = "applications/${var.aws_account}-${var.region}/${var.service_subtype}-${var.service}/qsp-transfer"
}
