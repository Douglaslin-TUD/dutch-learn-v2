"""
Configuration Encryptor for secure API key transfer.

Encrypts sensitive configuration (like OpenAI API key) for safe transfer
between desktop and mobile via Google Drive.
"""

import base64
import json
import secrets
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from app.config import settings


class ConfigEncryptionError(Exception):
    """Exception raised for config encryption errors."""
    pass


class ConfigEncryptor:
    """
    Encrypts and decrypts configuration for secure transfer.

    Uses password-based encryption (PBKDF2 + Fernet/AES-128-CBC).
    The password must be shared between desktop and mobile out-of-band.
    """

    # Salt for key derivation - fixed per installation
    # In production, this should be stored securely
    DEFAULT_SALT = b'dutch_learn_sync_salt_v1'

    def __init__(self, password: str, salt: Optional[bytes] = None):
        """
        Initialize encryptor with a password.

        Args:
            password: User-provided password for encryption
            salt: Optional salt for key derivation (uses default if not provided)
        """
        self.salt = salt or self.DEFAULT_SALT
        self._key = self._derive_key(password)
        self._fernet = Fernet(self._key)

    def _derive_key(self, password: str) -> bytes:
        """
        Derive an encryption key from password using PBKDF2.

        Args:
            password: User password

        Returns:
            Base64-encoded key suitable for Fernet
        """
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=self.salt,
            iterations=480000,  # OWASP recommended minimum
        )
        key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
        return key

    def encrypt_config(self, config: dict) -> str:
        """
        Encrypt configuration dictionary.

        Args:
            config: Dictionary containing configuration values

        Returns:
            Base64-encoded encrypted string
        """
        try:
            json_data = json.dumps(config).encode('utf-8')
            encrypted = self._fernet.encrypt(json_data)
            return base64.urlsafe_b64encode(encrypted).decode('ascii')
        except Exception as e:
            raise ConfigEncryptionError(f"Encryption failed: {e}")

    def decrypt_config(self, encrypted_data: str) -> dict:
        """
        Decrypt configuration from encrypted string.

        Args:
            encrypted_data: Base64-encoded encrypted string

        Returns:
            Decrypted configuration dictionary
        """
        try:
            encrypted = base64.urlsafe_b64decode(encrypted_data.encode('ascii'))
            decrypted = self._fernet.decrypt(encrypted)
            return json.loads(decrypted.decode('utf-8'))
        except Exception as e:
            raise ConfigEncryptionError(f"Decryption failed: {e}")


def generate_transfer_password() -> str:
    """
    Generate a secure, human-readable transfer password.

    Returns:
        A 16-character password using alphanumeric characters
    """
    # Use URL-safe base64 characters for easy typing
    alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
    return ''.join(secrets.choice(alphabet) for _ in range(16))


def export_config_for_mobile(password: str, output_path: Optional[Path] = None) -> dict:
    """
    Export encrypted configuration for mobile transfer.

    Args:
        password: Password for encryption
        output_path: Optional path to write the encrypted config file

    Returns:
        Dictionary with encrypted config and metadata
    """
    # Gather configuration to export
    config = {
        'openai_api_key': settings.openai_api_key or '',
        'exported_at': datetime.now(timezone.utc).isoformat(),
        'version': '1.0',
    }

    # Encrypt
    encryptor = ConfigEncryptor(password)
    encrypted = encryptor.encrypt_config(config)

    result = {
        'encrypted_config': encrypted,
        'version': '1.0',
        'algorithm': 'PBKDF2-SHA256-Fernet',
        'created_at': datetime.now(timezone.utc).isoformat(),
    }

    # Write to file if path provided
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2)

    return result


def import_config_from_mobile(encrypted_file_path: Path, password: str) -> dict:
    """
    Import and decrypt configuration from mobile transfer file.

    Args:
        encrypted_file_path: Path to the encrypted config file
        password: Password for decryption

    Returns:
        Decrypted configuration dictionary
    """
    with open(encrypted_file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    encryptor = ConfigEncryptor(password)
    return encryptor.decrypt_config(data['encrypted_config'])
