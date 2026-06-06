"""Tests for PrivacyRedactor."""
from app.services.privacy_redactor import PrivacyRedactor


class TestPrivacyRedactor:
    def setup_method(self):
        self.redactor = PrivacyRedactor()

    def test_redacts_api_key_field(self):
        payload = {"api_key": "sk-abc123xyz456", "model": "gpt-4"}
        result, hash_ = self.redactor.redact(payload)
        assert result["api_key"] == "[REDACTED]"
        assert result["model"] == "gpt-4"
        assert len(hash_) == 64  # SHA-256 hex

    def test_redacts_nested_secrets(self):
        payload = {"config": {"secret_key": "my-secret", "endpoint": "https://api.example.com"}}
        result, _ = self.redactor.redact(payload)
        assert result["config"]["secret_key"] == "[REDACTED]"
        assert result["config"]["endpoint"] == "https://api.example.com"

    def test_redacts_wallet_addresses(self):
        payload = {"note": "Send to 0x742d35Cc6634C0532925a3b844Bc9e7595f2bD28 please"}
        result, _ = self.redactor.redact(payload)
        assert "0x742d35" not in result["note"]
        assert "[WALLET_REDACTED]" in result["note"]

    def test_redacts_local_paths(self):
        payload = {"file": "/Users/mr_csx/workspace/phosphor-terminal/data.csv"}
        result, _ = self.redactor.redact(payload)
        assert "/Users/" not in result["file"]
        assert "[PATH_REDACTED]" in result["file"]

    def test_preserves_non_sensitive_data(self):
        payload = {"symbol": "BTC/USDT", "confidence": 0.85, "direction": "long"}
        result, _ = self.redactor.redact(payload)
        assert result == payload

    def test_input_hash_is_deterministic(self):
        payload = {"key": "value", "num": 42}
        _, hash1 = self.redactor.redact(payload)
        _, hash2 = self.redactor.redact(payload)
        assert hash1 == hash2
