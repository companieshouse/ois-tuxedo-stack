resource "aws_lambda_function" "qsp_transfer" {
  count      = local.qsp_transfer_count
  depends_on = [aws_cloudwatch_log_group.qsp_transfer]

  function_name = local.qsp_transfer_common_name
  s3_bucket     = var.qsp_transfer_bucket_name
  s3_key        = var.qsp_transfer_artifact_key
  role          = aws_iam_role.qsp_transfer[0].arn
  handler       = var.qsp_transfer_handler_name
  memory_size   = var.qsp_transfer_memory_size
  timeout       = var.qsp_transfer_timeout
  runtime       = var.qsp_transfer_runtime
  kms_key_arn   = aws_kms_key.ois.arn

  vpc_config {
    security_group_ids = [aws_security_group.qsp_transfer.id]
    subnet_ids         = data.aws_subnet.application.*.id
  }

  environment {
    variables = {
      DATA_FILE_PREFIX = "CreditCard"
      FTP_HOST         = var.qsp_transfer_ftp_host
      FTP_PATH         = var.qsp_transfer_ftp_path
      LOG_GROUP_NAME   = local.qsp_transfer_log_group_name
      SECRET_NAME      = local.qsp_transfer_common_name
    }
  }
}

resource "aws_security_group" "qsp_transfer" {
  name   = local.qsp_transfer_common_name
  vpc_id = data.aws_vpc.heritage.id

  ingress {
    description = "Allow inbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_event_rule" "qsp_transfer" {
  count = local.qsp_transfer_count

  name                = local.qsp_transfer_common_name
  description         = "QSP transfer Lambda Function event rule"
  schedule_expression = var.qsp_transfer_schedule
}

resource "aws_cloudwatch_event_target" "qsp_transfer" {
  count = local.qsp_transfer_count

  arn       = aws_lambda_function.qsp_transfer[0].arn
  rule      = aws_cloudwatch_event_rule.qsp_transfer[0].name
  target_id = "InvokeQSPTransfer"
}

resource "aws_lambda_permission" "qsp_transfer" {
  count = local.qsp_transfer_count

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.qsp_transfer[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.qsp_transfer[0].arn
}

resource "aws_cloudwatch_log_group" "qsp_transfer" {
  count = local.qsp_transfer_count

  name              = "/aws/lambda/${local.qsp_transfer_common_name}"
  retention_in_days = var.qsp_transfer_log_retention_in_days
}

resource "aws_iam_role" "qsp_transfer" {
  count      = local.qsp_transfer_count
  depends_on = [aws_cloudwatch_log_group.qsp_transfer]

  name               = local.qsp_transfer_common_name
  assume_role_policy = data.aws_iam_policy_document.qsp_transfer_trust.json
}

resource "aws_iam_policy" "qsp_transfer_execution" {
  count = local.qsp_transfer_count

  name        = local.qsp_transfer_common_name
  description = "QSP transfer Lambda Function policy"
  policy      = data.aws_iam_policy_document.qsp_transfer_execution.json
}

resource "aws_iam_role_policy_attachment" "qsp_transfer_execution" {
  count = local.qsp_transfer_count

  role       = aws_iam_role.qsp_transfer[0].name
  policy_arn = aws_iam_policy.qsp_transfer_execution[0].arn
}

resource "aws_iam_role_policy_attachment" "qsp_transfer_vpc_access" {
  count = local.qsp_transfer_count

  role       = aws_iam_role.qsp_transfer[0].name
  policy_arn = data.aws_iam_policy.qsp_transfer_vpc_access.arn
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

      resources = ["${aws_cloudwatch_log_group.tuxedo[local.qsp_transfer_log_group_name].arn}:*"]
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

resource "aws_secretsmanager_secret" "qsp_transfer" {
  name = local.qsp_transfer_common_name
}

resource "aws_secretsmanager_secret_version" "qsp_transfer" {
  secret_id     = aws_secretsmanager_secret.qsp_transfer.id
  secret_string = jsonencode(data.vault_generic_secret.qsp_transfer.data)
}

data "aws_iam_policy" "qsp_transfer_vpc_access" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
