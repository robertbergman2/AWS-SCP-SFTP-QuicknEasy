data "archive_file" "auth_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/auth.py"
  output_path = "${path.module}/lambda/auth.zip"
}

resource "aws_lambda_function" "auth" {
  function_name    = "${var.project_name}-${var.environment}-sftp-auth"
  filename         = data.archive_file.auth_lambda.output_path
  source_code_hash = data.archive_file.auth_lambda.output_base64sha256
  handler          = "auth.handler"
  runtime          = "python3.13"
  timeout          = 10
  role             = aws_iam_role.lambda_auth.arn

  environment {
    variables = {
      SECRET_PREFIX = "${var.project_name}/${var.environment}/sftp-user-"
    }
  }
}

resource "aws_lambda_permission" "transfer_invoke" {
  statement_id  = "AllowTransferFamilyInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "transfer.amazonaws.com"
  source_arn    = aws_transfer_server.sftp.arn
}
