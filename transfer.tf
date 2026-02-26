resource "aws_transfer_server" "sftp" {
  protocols              = ["SFTP"]
  endpoint_type          = "PUBLIC"
  identity_provider_type = "AWS_LAMBDA"
  function               = aws_lambda_function.auth.arn
  logging_role           = aws_iam_role.transfer_logging.arn

  protocol_details {
    set_stat_option = "ENABLE_NO_OP"
  }

  structured_log_destinations = [
    "${aws_cloudwatch_log_group.transfer.arn}:*"
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

