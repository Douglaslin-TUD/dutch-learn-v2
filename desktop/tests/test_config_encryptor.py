# desktop/tests/test_config_encryptor.py
"""Tests for desktop/app/services/config_encryptor.py."""

import json

import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

from app.services.config_encryptor import (
    ConfigEncryptor,
    ConfigEncryptionError,
    generate_transfer_password,
    export_config_for_mobile,
    import_config_from_mobile,
)


class TestConfigEncryptor:
    """Tests for the ConfigEncryptor class."""

    def test_encrypt_decrypt_round_trip(self):
        """Encrypting then decrypting should return the original config."""
        password = "test-password-123"
        encryptor = ConfigEncryptor(password)
        config = {"api_key": "sk-test-12345", "model": "gpt-4o-mini"}

        encrypted = encryptor.encrypt_config(config)
        assert isinstance(encrypted, str)
        assert "sk-test-12345" not in encrypted

        decrypted = encryptor.decrypt_config(encrypted)
        assert decrypted == config

    def test_wrong_password_fails(self):
        """Decrypting with a different password should raise ConfigEncryptionError."""
        encryptor1 = ConfigEncryptor("correct-password")
        encryptor2 = ConfigEncryptor("wrong-password")

        encrypted = encryptor1.encrypt_config({"key": "value"})

        with pytest.raises(ConfigEncryptionError):
            encryptor2.decrypt_config(encrypted)

    def test_custom_salt(self):
        """A custom salt should still allow round-trip encrypt/decrypt."""
        salt = b"custom_salt_bytes"
        encryptor = ConfigEncryptor("password", salt=salt)
        config = {"key": "value"}
        encrypted = encryptor.encrypt_config(config)
        decrypted = encryptor.decrypt_config(encrypted)
        assert decrypted == config

    def test_empty_config(self):
        """Encrypting an empty dict should round-trip correctly."""
        encryptor = ConfigEncryptor("password")
        encrypted = encryptor.encrypt_config({})
        decrypted = encryptor.decrypt_config(encrypted)
        assert decrypted == {}

    def test_default_salt_used_when_none(self):
        """When no salt is provided, the default should be used."""
        encryptor = ConfigEncryptor("password")
        assert encryptor.salt == ConfigEncryptor.DEFAULT_SALT

    def test_different_salts_produce_different_ciphertext(self):
        """Same password with different salts should produce different output."""
        enc1 = ConfigEncryptor("password", salt=b"salt_one")
        enc2 = ConfigEncryptor("password", salt=b"salt_two")
        config = {"key": "value"}
        encrypted1 = enc1.encrypt_config(config)
        encrypted2 = enc2.encrypt_config(config)
        # Different salts mean different keys, so different ciphertext
        assert encrypted1 != encrypted2

    def test_decrypt_invalid_data_raises_error(self):
        """Decrypting garbage data should raise ConfigEncryptionError."""
        encryptor = ConfigEncryptor("password")
        with pytest.raises(ConfigEncryptionError):
            encryptor.decrypt_config("not-valid-encrypted-data")


class TestGenerateTransferPassword:
    """Tests for the generate_transfer_password function."""

    def test_length(self):
        """Generated password should be exactly 16 characters."""
        password = generate_transfer_password()
        assert len(password) == 16

    def test_uniqueness(self):
        """Two generated passwords should not be equal."""
        a = generate_transfer_password()
        b = generate_transfer_password()
        assert a != b

    def test_characters_are_alphanumeric(self):
        """Generated password should contain only alphanumeric characters."""
        password = generate_transfer_password()
        # The alphabet used excludes ambiguous chars like O, 0, l, 1, I
        # but all chars are still alphanumeric
        assert password.isalnum()


class TestExportImportConfig:
    """Tests for export_config_for_mobile and import_config_from_mobile."""

    @patch("app.services.config_encryptor.settings")
    def test_export_creates_file(self, mock_settings, tmp_path):
        """Exporting should create the encrypted config file."""
        mock_settings.openai_api_key = "sk-test-key"

        output_path = tmp_path / "config.enc"
        password = "test-password"

        result = export_config_for_mobile(password, output_path=output_path)
        assert output_path.exists()
        assert "encrypted_config" in result
        assert result["version"] == "1.0"
        assert result["algorithm"] == "PBKDF2-SHA256-Fernet"

    @patch("app.services.config_encryptor.settings")
    def test_export_import_round_trip(self, mock_settings, tmp_path):
        """Exporting and then importing should recover the original API key."""
        mock_settings.openai_api_key = "sk-test-key"

        output_path = tmp_path / "config.enc"
        password = "test-password"

        export_config_for_mobile(password, output_path=output_path)

        imported = import_config_from_mobile(output_path, password)
        assert imported["openai_api_key"] == "sk-test-key"

    @patch("app.services.config_encryptor.settings")
    def test_export_without_file(self, mock_settings):
        """Exporting without output_path should return result without writing."""
        mock_settings.openai_api_key = "sk-key"

        result = export_config_for_mobile("password")
        assert "encrypted_config" in result
        assert result["version"] == "1.0"

    @patch("app.services.config_encryptor.settings")
    def test_import_wrong_password_fails(self, mock_settings, tmp_path):
        """Importing with the wrong password should raise ConfigEncryptionError."""
        mock_settings.openai_api_key = "sk-secret"

        output_path = tmp_path / "config.enc"
        export_config_for_mobile("correct-password", output_path=output_path)

        with pytest.raises(ConfigEncryptionError):
            import_config_from_mobile(output_path, "wrong-password")
