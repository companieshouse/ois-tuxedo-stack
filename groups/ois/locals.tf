locals {
  application_subnet_ids_by_az = values(zipmap(data.aws_subnet.application[*].availability_zone, data.aws_subnet.application[*].id))

  common_tags = {
    Environment    = var.environment
    Service        = var.service
    ServiceSubType = var.service_subtype
    Team           = var.team
  }

  common_resource_name = "${var.service_subtype}-${var.service}-${var.environment}"
  dns_zone = "${var.environment}.${var.dns_zone_suffix}"

  security_s3_data            = data.vault_generic_secret.security_s3_buckets.data
  session_manager_bucket_name = local.security_s3_data.session-manager-bucket-name

  security_kms_keys_data      = data.vault_generic_secret.security_kms_keys.data
  ssm_kms_key_id              = local.security_kms_keys_data.session-manager-kms-key-arn

  tuxedo_log_groups = merge([
    for tuxedo_service_group, log_groups in var.tuxedo_log_groups : {
      for log_group in log_groups : "${var.service_subtype}-${var.service}-${tuxedo_service_group}-${lower(log_group.name)}" => {
        log_retention_in_days = log_group.log_retention_in_days != null ? log_group.log_retention_in_days : var.default_log_retention_in_days
        kms_key_id            = log_group.kms_key_id != null ? log_group.kms_key_id : local.logs_kms_key_id
        tuxedo_service        = tuxedo_service_group
        log_name              = log_group.name
        log_type              = "individual"
      }
    }
  ]...)

  tuxedo_log_group_arns = [
    for log_group in merge(
      aws_cloudwatch_log_group.tuxedo,
      { "cloudwatch" = aws_cloudwatch_log_group.cloudwatch }
    )
    : log_group.arn
  ]

  kms_key_administrator_arns = concat(tolist(data.aws_iam_roles.sso_administrator.arns), [data.aws_iam_user.concourse.arn])

  logs_kms_key_id = data.vault_generic_secret.kms_keys.data["logs"]

  qsp_transfer_count       = var.qsp_transfer_enabled ? 1 : 0
  qsp_transfer_common_name = "${local.common_resource_name}-qsp-transfer"
}
