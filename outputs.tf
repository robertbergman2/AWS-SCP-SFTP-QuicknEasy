output "transfer_server_id" {
  description = "AWS Transfer Family server ID"
  value       = aws_transfer_server.sftp.id
}

output "transfer_server_endpoint" {
  description = "SFTP/SCP server endpoint hostname"
  value       = aws_transfer_server.sftp.endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket name for SFTP storage"
  value       = aws_s3_bucket.sftp.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.sftp.arn
}

output "scp_example_command" {
  description = "Example SCP command"
  value       = "scp testfile.txt USER@${aws_transfer_server.sftp.endpoint}:/testfile.txt"
}

output "sftp_example_command" {
  description = "Example SFTP command"
  value       = "sftp USER@${aws_transfer_server.sftp.endpoint}"
}
