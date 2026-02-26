"""AWS Transfer Family custom identity provider for password and SSH key authentication.

Implements the Transfer Family custom identity provider contract.
Credentials are stored in AWS Secrets Manager as:
    {project_name}/{environment}/sftp-user-{username}

Each secret value is a JSON object:
    {
        "password": "the-password",          # optional — omit for key-only users
        "public_keys": ["ssh-rsa AAAA..."],  # optional — omit for password-only users
        "role_arn": "arn:aws:iam::...:role/...",
        "home_directory": "/bucket/prefix"
    }

Auth logic:
    - Password provided  → validate password, deny if wrong
    - No password        → return stored public keys for Transfer Family key verification
    - Both configured    → a user can connect either way
"""

import json
import os

import boto3

secrets_client = boto3.client("secretsmanager")

SECRET_PREFIX = os.environ["SECRET_PREFIX"]


def _fetch_secret(username: str) -> dict | None:
    """Fetch and parse user secret from Secrets Manager.

    Returns the parsed secret dict, or None if the user is not found.
    Raises on unexpected errors.
    """
    secret_name = f"{SECRET_PREFIX}{username}"
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        return json.loads(response["SecretString"])
    except secrets_client.exceptions.ResourceNotFoundException:
        return None


def _auth_response(secret: dict) -> dict:
    """Build the successful Transfer Family auth response from a secret."""
    return {
        "Role": secret["role_arn"],
        "HomeDirectoryType": "LOGICAL",
        "HomeDirectoryDetails": json.dumps(
            [{"Entry": "/", "Target": secret["home_directory"]}]
        ),
    }


def handler(event: dict, context: object) -> dict:
    """Handle Transfer Family authentication request.

    Args:
        event: Transfer Family auth event containing username, password,
               protocol, serverId, and sourceIp.
        context: Lambda context (unused).

    Returns:
        Dict with Role, HomeDirectory, and optionally PublicKeys on success,
        or empty dict on failure.
    """
    username = event.get("username", "")
    password = event.get("password", "")
    protocol = event.get("protocol", "")
    server_id = event.get("serverId", "")

    print(
        json.dumps(
            {
                "action": "auth_attempt",
                "username": username,
                "protocol": protocol,
                "server_id": server_id,
                "source_ip": event.get("sourceIp", "unknown"),
                "auth_type": "password" if password else "public_key",
            }
        )
    )

    try:
        secret = _fetch_secret(username)
    except Exception as exc:
        print(json.dumps({"action": "auth_error", "reason": str(exc)}))
        return {}

    if secret is None:
        print(json.dumps({"action": "auth_fail", "reason": "user_not_found", "username": username}))
        return {}

    if password:
        # Password authentication
        stored_password = secret.get("password", "")
        if not stored_password or password != stored_password:
            print(json.dumps({"action": "auth_fail", "reason": "invalid_password", "username": username}))
            return {}

        print(json.dumps({"action": "auth_success", "username": username, "auth_type": "password"}))
        return _auth_response(secret)

    else:
        # SSH public key authentication — return stored keys; Transfer Family
        # validates the user's presented key against this list.
        public_keys = secret.get("public_keys", [])
        if not public_keys:
            print(json.dumps({"action": "auth_fail", "reason": "no_public_keys_configured", "username": username}))
            return {}

        print(json.dumps({"action": "auth_success", "username": username, "auth_type": "public_key"}))
        response = _auth_response(secret)
        response["PublicKeys"] = public_keys
        return response
