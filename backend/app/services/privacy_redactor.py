"""Privacy redaction for cloud-bound AI payloads."""
import hashlib
import json
import re
from typing import Any

# Patterns to detect and redact
API_KEY_PATTERNS = [
    re.compile(
        r'(?i)(api[_-]?key|secret|token|password|credential|auth)'
        r'["\s:=]+["\']?([a-zA-Z0-9_\-./+=]{16,})["\']?'
    ),
]
WALLET_PATTERN = re.compile(
    r'\b(0x[a-fA-F0-9]{40}|[13][a-km-zA-HJ-NP-Z1-9]{25,34}|bc1[a-zA-HJ-NP-Z0-9]{39,59})\b'
)
LOCAL_PATH_PATTERN = re.compile(
    r'(/Users/[^\s"\']+|/home/[^\s"\']+|C:\\\\Users\\\\[^\s"\']+)'
)
ACCOUNT_ID_PATTERN = re.compile(
    r'(?i)(account[_-]?id|user[_-]?id)["\s:=]+["\']?([a-zA-Z0-9_\-]{8,})["\']?'
)


class PrivacyRedactor:
    """Strips sensitive data from payloads before sending to cloud AI providers."""

    SENSITIVE_KEYS = {
        "api_key", "api_secret", "secret_key", "access_token", "refresh_token",
        "password", "credential", "private_key", "secret", "token",
        "api_key_encrypted", "exchange_key", "exchange_secret",
    }

    def redact(self, payload: dict) -> tuple[dict, str]:
        """Returns (redacted_payload, input_hash)."""
        input_hash = hashlib.sha256(
            json.dumps(payload, sort_keys=True, default=str).encode()
        ).hexdigest()
        redacted = self._redact_dict(payload)
        return redacted, input_hash

    def _redact_dict(self, d: dict) -> dict:
        result = {}
        for k, v in d.items():
            if k.lower() in self.SENSITIVE_KEYS:
                result[k] = "[REDACTED]"
            elif isinstance(v, dict):
                result[k] = self._redact_dict(v)
            elif isinstance(v, list):
                result[k] = [
                    self._redact_dict(i) if isinstance(i, dict) else self._redact_value(i)
                    for i in v
                ]
            elif isinstance(v, str):
                result[k] = self._redact_string(v)
            else:
                result[k] = v
        return result

    def _redact_string(self, s: str) -> str:
        s = WALLET_PATTERN.sub("[WALLET_REDACTED]", s)
        s = LOCAL_PATH_PATTERN.sub("[PATH_REDACTED]", s)
        for pattern in API_KEY_PATTERNS:
            s = pattern.sub(lambda m: f'{m.group(1)}="[REDACTED]"', s)
        s = ACCOUNT_ID_PATTERN.sub(lambda m: f'{m.group(1)}="[ID_REDACTED]"', s)
        return s

    def _redact_value(self, v: Any) -> Any:
        if isinstance(v, str):
            return self._redact_string(v)
        return v
