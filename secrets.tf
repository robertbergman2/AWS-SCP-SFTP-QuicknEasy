resource "aws_secretsmanager_secret" "sftp_user" {
  for_each = var.sftp_users

  name = "${var.project_name}/${var.environment}/sftp-user-${each.key}"
}

resource "aws_secretsmanager_secret_version" "sftp_user" {
  for_each = var.sftp_users

  secret_id = aws_secretsmanager_secret.sftp_user[each.key].id
  secret_string = jsonencode({
    role_arn       = aws_iam_role.transfer_user[each.key].arn
    home_directory = "/${aws_s3_bucket.sftp.id}/${coalesce(each.value.home_directory, each.key)}"
  })
}

resource "aws_secretsmanager_secret" "keycloak_client_secret" {
  name = "${var.project_name}/${var.environment}/keycloak-client-secret"
}

resource "aws_secretsmanager_secret_version" "keycloak_client_secret" {
  secret_id     = aws_secretsmanager_secret.keycloak_client_secret.id
  secret_string = var.keycloak_client_secret
}

