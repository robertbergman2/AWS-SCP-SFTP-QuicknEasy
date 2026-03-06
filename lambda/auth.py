"""AWS Transfer Family custom identity provider using Keycloak.

Authenticates SSH keys by querying Keycloak Admin API for a custom attribute.
User's IAM role and home directory are still loaded from AWS Secrets Manager.
"""

import json
import os
import urllib.error
import urllib.parse
import urllib.request

import boto3

secrets_client = boto3.client("secretsmanager")

SECRET_PREFIX = os.environ["SECRET_PREFIX"]
KEYCLOAK_URL = os.environ["KEYCLOAK_URL"].rstrip("/")
KEYCLOAK_REALM = os.environ["KEYCLOAK_REALM"]
KEYCLOAK_CLIENT_ID = os.environ["KEYCLOAK_CLIENT_ID"]
KEYCLOAK_SECRET_ID = os.environ["KEYCLOAK_SECRET_ID"]


def _fetch_secret(secret_name: str) -> str | None:
    """Fetch string secret from Secrets Manager."""
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        return response["SecretString"]
    except secrets_client.exceptions.ResourceNotFoundException:
        return None


def _fetch_user_config(username: str) -> dict | None:
    """Fetch user's AWS config (role and home dir) from Secrets Manager."""
    secret_name = f"{SECRET_PREFIX}{username}"
    secret_string = _fetch_secret(secret_name)
    if not secret_string:
        return None
    return json.loads(secret_string)


def _get_keycloak_token() -> str | None:
    """Obtain access token from Keycloak using client credentials."""
    client_secret = _fetch_secret(KEYCLOAK_SECRET_ID)
    if not client_secret:
        print(json.dumps({"action": "error", "reason": "keycloak_secret_not_found"}))
        return None

    url = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/token"
    data = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": KEYCLOAK_CLIENT_ID,
            "client_secret": client_secret,
        }
    ).encode("utf-8")

    req = urllib.request.Request(url, data=data)
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            result = json.loads(response.read())
            return result.get("access_token")
    except Exception as exc:
        print(json.dumps({"action": "keycloak_token_error", "reason": str(exc)}))
        return None


def _get_user_ssh_keys(token: str, username: str) -> list[str]:
    """Query Keycloak Admin API for user's sshPublicKey attribute."""
    query = urllib.parse.urlencode({"username": username, "exact": "true"})
    url = f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users?{query}"

    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {token}")

    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            users = json.loads(response.read())
            if not users:
                return []

            user = users[0]
            attributes = user.get("attributes", {})
            ssh_keys = attributes.get("sshPublicKey", [])
            return ssh_keys
    except Exception as exc:
        print(json.dumps({"action": "keycloak_api_error", "reason": str(exc)}))
        return []


def handler(event: dict, context: object) -> dict:
    """Handle Transfer Family authentication request."""
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
                "auth_type": "password" if password else "public_key",
            }
        )
    )

    if password:
        print(
            json.dumps(
                {
                    "action": "auth_fail",
                    "reason": "password_auth_disabled",
                    "username": username,
                }
            )
        )
        return {}

    try:
        user_config = _fetch_user_config(username)
    except Exception as exc:
        print(json.dumps({"action": "aws_config_error", "reason": str(exc)}))
        return {}

    if not user_config:
        print(
            json.dumps(
                {
                    "action": "auth_fail",
                    "reason": "user_not_configured_in_aws",
                    "username": username,
                }
            )
        )
        return {}

    token = _get_keycloak_token()
    if not token:
        print(json.dumps({"action": "auth_fail", "reason": "keycloak_auth_failed"}))
        return {}

    public_keys = _get_user_ssh_keys(token, username)
    if not public_keys:
        print(
            json.dumps(
                {
                    "action": "auth_fail",
                    "reason": "no_public_keys_in_keycloak",
                    "username": username,
                }
            )
        )
        return {}

    print(
        json.dumps(
            {
                "action": "auth_success",
                "username": username,
                "auth_type": "public_key",
            }
        )
    )

    return {
        "Role": user_config["role_arn"],
        "HomeDirectoryType": "LOGICAL",
        "HomeDirectoryDetails": json.dumps(
            [{"Entry": "/", "Target": user_config["home_directory"]}]
        ),
        "PublicKeys": public_keys,
    }
