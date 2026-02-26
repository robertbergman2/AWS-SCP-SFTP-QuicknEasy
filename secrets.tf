resource "aws_secretsmanager_secret" "sftp_user" {
  for_each = var.sftp_users

  name = "${var.project_name}/${var.environment}/sftp-user-${each.key}"
}

resource "aws_secretsmanager_secret_version" "sftp_user" {
  for_each = var.sftp_users

  secret_id = aws_secretsmanager_secret.sftp_user[each.key].id
  secret_string = jsonencode({
    password       = each.value.password
    public_keys    = each.value.public_keys
    role_arn       = aws_iam_role.transfer_user[each.key].arn
    home_directory = "/${aws_s3_bucket.sftp.id}/${coalesce(each.value.home_directory, each.key)}"
  })
}
