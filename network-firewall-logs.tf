locals {
  enable_firewall_logs = var.create_vpc && var.enable_firewall && var.enable_firewall_logs
  use_s3logs = local.enable_firewall_logs && var.firewall_logs_destination == "S3"
  use_cloudwatchlogs = local.enable_firewall_logs && var.firewall_logs_destination == "CloudWatchLogs"
}

########################
# Network Firewall Logs
########################
resource "aws_networkfirewall_logging_configuration" "this" {
  count        = local.enable_firewall_logs && length(var.firewall_log_types) > 0 ? 1 : 0
  depends_on   = [aws_cloudwatch_log_group.firewall_log]
  firewall_arn = aws_networkfirewall_firewall.this[0].arn

  logging_configuration {
    dynamic "log_destination_config" {
      for_each = var.firewall_log_types

      content {
        log_destination = {
          logGroup = local.use_cloudwatchlogs ? aws_cloudwatch_log_group.firewall_log[log_destination_config.key].id : null
          bucketName = local.use_s3logs ? var.firewall_log_s3_bucket_name : null
          prefix = local.use_s3logs ? var.firewall_log_s3_bucket_prefix : null
        }
        log_destination_type = var.firewall_logs_destination
        log_type             = log_destination_config.value
      }
    }
  }
}

###################################
# Network Firewall Logs Cloudwatch
###################################
resource "aws_cloudwatch_log_group" "firewall_log" {
  count = local.enable_firewall_logs && local.use_cloudwatchlogs ? length(var.firewall_log_types) : 0

  name              = "${var.firewall_log_cloudwatch_log_group_name_prefix}${local.vpc_id}-${lower(element(var.firewall_log_types, count.index))}"
  retention_in_days = var.firewall_log_cloudwatch_log_group_retention_in_days
  kms_key_id        = var.firewall_log_cloudwatch_log_group_kms_key_id

  tags = merge(var.tags, var.firewall_log_tags)
}
