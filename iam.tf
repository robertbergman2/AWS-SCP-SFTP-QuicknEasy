# -----------------------------------------------------------------------------
# Transfer Family logging role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "transfer_logging" {
  name = "${var.project_name}-${var.environment}-transfer-logging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "transfer.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "transfer_logging" {
  name = "cloudwatch-logs"
  role = aws_iam_role.transfer_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:CreateLogGroup",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.transfer.arn}:*"
    }]
  })
}

# -----------------------------------------------------------------------------
# Per-user Transfer Family role (scoped S3 access)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "transfer_user" {
  for_each = var.sftp_users

  name = "${var.project_name}-${var.environment}-user-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "transfer.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "transfer_user" {
  for_each = var.sftp_users

  name = "s3-access"
  role = aws_iam_role.transfer_user[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.sftp.arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "${coalesce(each.value.home_directory, each.key)}/*",
              "${coalesce(each.value.home_directory, each.key)}"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.sftp.arn}/${coalesce(each.value.home_directory, each.key)}/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda execution role (for password auth function)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_auth" {
  name = "${var.project_name}-${var.environment}-lambda-auth"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_auth.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "secrets-manager-read"
  role = aws_iam_role.lambda_auth.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/sftp-user-*"
    }]
  })
}
