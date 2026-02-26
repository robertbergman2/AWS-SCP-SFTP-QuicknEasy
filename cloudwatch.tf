resource "aws_cloudwatch_log_group" "transfer" {
  name              = "/aws/transfer/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
}
