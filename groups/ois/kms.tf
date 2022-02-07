data "aws_iam_roles" "sso_administrator" {
  name_regex  = "AWSReservedSSO_AdministratorAccess.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/${var.region}"
}

data "aws_iam_user" "concourse" {
    user_name = "concourse-platform"
}

resource "aws_kms_key" "ois" {
  description         = "KMS key for OIS Tuxedo services"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.ois.json

  tags = merge(local.common_tags, {
    Name = local.common_resource_name
  })
}

resource "aws_kms_alias" "ois" {
  name          = "alias/${local.common_resource_name}"
  target_key_id = aws_kms_key.ois.key_id
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
      identifiers = concat(tolist(data.aws_iam_roles.sso_administrator.arns), [data.aws_iam_user.concourse.arn])
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}
