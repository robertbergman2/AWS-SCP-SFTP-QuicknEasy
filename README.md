# AWS Transfer Family SFTP/SCP Server

Public-facing AWS Transfer Family server backed by S3, supporting SFTP and SCP protocols with password and SSH public key authentication via AWS Secrets Manager.

## Architecture

```
User (scp/sftp) --> AWS Transfer Family (public endpoint)
                        |
                        +--> S3 Bucket (storage)
                        +--> Lambda (password auth via custom identity provider)
                        +--> IAM Roles (Transfer Family + user access)
                        +--> CloudWatch Logs (structured logging)
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with profile `YOUR_AWS_PROFILE`

## Quick Start

```bash
# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your user configurations

# Deploy
terraform init
terraform plan
terraform apply
```

## Adding Users

Users support **password auth**, **SSH public key auth**, or both. At least one must be configured.

1. Add users to `terraform.tfvars`:

```hcl
sftp_users = {
  # Password only
  "alice" = {
    password       = "secure-password-here"
    home_directory = null  # defaults to "alice"
  }
  # SSH key only
  "bob" = {
    public_keys    = ["ssh-rsa AAAA... bob@example.com"]
    home_directory = "team-uploads"
  }
  # Both
  "carol" = {
    password    = "secure-password-here"
    public_keys = ["ssh-rsa AAAA... carol@example.com"]
  }
}
```

1. Run `terraform apply` — this creates the IAM role and Secrets Manager secret for each user.

The secret is populated automatically from `terraform.tfvars`. To update credentials outside of Terraform:

```bash
# Password + key user
aws secretsmanager put-secret-value \
  --secret-id "sftp-external/dev/sftp-user-alice" \
  --secret-string '{
    "password": "new-password",
    "public_keys": ["ssh-rsa AAAA... alice@example.com"],
    "role_arn": "arn:aws:iam::ACCOUNT:role/sftp-external-dev-user-alice",
    "home_directory": "/BUCKET_NAME/alice"
  }' \
  --profile YOUR_AWS_PROFILE
```

## Usage

After `terraform apply`, use the endpoint from the outputs:

```bash
# SCP
scp testfile.txt user@SERVER_ENDPOINT:/testfile.txt

# SFTP
sftp user@SERVER_ENDPOINT

# Verify in S3
aws s3 ls s3://BUCKET_NAME/username/ --profile YOUR_AWS_PROFILE
```

## Outputs

| Output | Description |
|--------|-------------|
| `transfer_server_id` | Transfer Family server ID |
| `transfer_server_endpoint` | SFTP/SCP endpoint hostname |
| `s3_bucket_name` | S3 bucket name |
| `s3_bucket_arn` | S3 bucket ARN |
| `scp_example_command` | Example SCP command |
| `sftp_example_command` | Example SFTP command |
