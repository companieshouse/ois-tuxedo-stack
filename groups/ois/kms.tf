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
