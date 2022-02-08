variable "ami_owner_id" {
  type        = string
  description = "The AMI owner ID"
}

variable "ami_version_pattern" {
  type        = string
  description = "The pattern to use when filtering for AMI version by name"
  default     = "*"
}

variable "application_subnet_pattern" {
  type        = string
  description = "The pattern to use when filtering for application subnets by 'Name' tag"
  default     = "sub-application-*"
}

variable "aws_account" {
  type        = string
  description = "The name of the AWS account; used in Vault path when looking up account identifier"
}

variable "chips_cidr" {
  type        = string
  description = "A string representing the CIDR range from which CHIPS instances will connect to Tuxedo services"
}

variable "default_log_retention_in_days" {
  type        = string
  description = "The default log retention period in days for CloudWatch log groups"
  default     = 7
}

variable "deployment_cidrs" {
  type        = list(string)
  description = "A list of strings representing CIDR ranges from which applications will be deployed to Tuxedo instances via Ansible"
}

variable "dns_zone_suffix" {
  type        = string
  description = "The common DNS hosted zone suffix used across accounts"
  default     = "heritage.aws.internal"
}

variable "environment" {
  type        = string
  description = "The environment name to be used when creating AWS resources"
}

variable "instance_count" {
  type        = number
  description = "The number of instances to create"
  default     = 1
}

variable "instance_type" {
  type        = string
  description = "The instance type to use"
  default     = "t3.small"
}

variable "lvm_block_devices" {
  type = list(object({
    aws_volume_size_gb: string,
    filesystem_resize_tool: string,
    lvm_logical_volume_device_node: string,
    lvm_physical_volume_device_node: string,
  }))
  description = "A list of objects representing LVM block devices; each LVM volume group is assumed to contain a single physical volume and each logical volume is assumed to belong to a single volume group; the filesystem for each logical volume will be expanded to use all available space within the volume group using the filesystem resize tool specified; block device configuration applies only on resource creation. Set the 'filesystem_resize_tool' and 'lvm_logical_volume_device_node' fields to empty strings if the block device contains no filesystem and should be excluded from the automatic filesystem resizing, such as when the block device represents a swap volume"
  default = []
}

variable "qsp_transfer_artifact_key" {
  type        = string
  description = "The release artifact key for the QSP transfer Lambda Function"
}

variable "qsp_transfer_bucket_name" {
  type        = string
  description = "The name of the S3 bucket containing the release artifact for the QSP transfer Lambda Function"
}

variable "qsp_transfer_enabled" {
  type        = bool
  description = "A boolean value representing whether to enable the QSP transfer Lambda Function or not."
  default     = false
}

variable "qsp_transfer_ftp_host" {
  type        = string
  description = "The FTP host to be used for QSP data transfers"
}

variable "qsp_transfer_ftp_path" {
  type        = string
  description = "The path to upload QSP data transfers to"
  default     = "upload"
}

variable "qsp_transfer_handler_name" {
  type        = string
  description = "The Lambda Function entrypoint"
  default     = "qsp_transfer.lambda_handler"
}

variable "qsp_transfer_log_group_name" {
  type        = string
  description = "The name of the log group containing data to be processed by the QSP transfer Lambda Function"
}

variable "qsp_transfer_log_retention_in_days" {
  type        = number
  description = "The default retention period in days for QSP transfer logs"
  default     = 7
}

variable "qsp_transfer_memory_size" {
  type        = string
  description = "The amount of memory the Lambda Function can use at runtime in megabytes"
  default     = "512"
}

variable "qsp_transfer_runtime" {
  type        = string
  description = "The  runtime to use for the Lambda Function"
  default     = "python3.9"
}

variable "qsp_transfer_schedule" {
  type        = string
  description = "A string representing the QSP transfer Lambda Function schedule. For example, cron(0 20 * * ? *) or rate(5 minutes)."
  default     = "cron(0 15 * * ? *)"
}

variable "qsp_transfer_timeout" {
  type        = string
  description = "The amount of time the Lambda Function is allowed to run before being stopped"
  default     = 60
}

variable "lb_deletion_protection" {
  type        = bool
  description = "A boolean value representing whether to enable load balancer deletion protection"
  default     = false
}

variable "region" {
  type        = string
  description = "The AWS region in which resources will be administered"
}

variable "root_volume_size" {
  type        = number
  description = "The size of the root volume in gibibytes (GiB)"
  default     = 20
}

variable "service" {
  type        = string
  description = "The service name to be used when creating AWS resources"
  default     = "tuxedo"
}

variable "service_subtype" {
  type        = string
  description = "The service subtype name to be used when creating AWS resources"
  default     = "ois"
}

variable "tuxedo_service_logs" {
  type        = map(list(any))
  description = "A map whose keys represent server-side tuxedo server groups with lists of objects representing user log files for each server group. Each object is expected to have at a minimum a 'name' key. Optional 'log_retention_in_days' and 'kms_key_id' attributes can be set per-file to override the default values and will apply to both standard error and standard output log groups for that log."
}

variable "tuxedo_user_logs" {
  type        = map(list(any))
  description = "A map whose keys represent server-side tuxedo server groups with lists of objects representing individual log files for each server group. Each object is expected to have at a minimum a 'name' key. A single CloudWatch log group will be created for each object. Optional 'log_retention_in_days' and 'kms_key_id' attributes can be set per-file to override the default values."
}

variable "tuxedo_services" {
  type        = map(number)
  description = "A map whose key-value pairs represent server-side tuxedo server groups and assocaited port numbers"
  default = {
    ceu  = 38000,
    ois  = 38100,
    publ = 38200,
    xml  = 38300,
    wck  = 38400,
  }
}

variable "ssh_master_public_key" {
  type        = string
  description = "The SSH master public key; EC2 instance connect should be used for regular connectivity"
}

variable "team" {
  type        = string
  description = "The team name for ownership of this service"
  default     = "Platform"
}

variable "user_data_merge_strategy" {
  default     = "list(append)+dict(recurse_array)+str()"
  description = "Merge strategy to apply to user-data sections for cloud-init"
}
