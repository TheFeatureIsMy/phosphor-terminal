"""
General utility functions
"""
import hashlib
import secrets
import string
from datetime import datetime, timezone
from typing import Any


def utcnow() -> datetime:
    """Get current UTC time"""
    return datetime.now(timezone.utc)


def generate_random_string(length: int = 32) -> str:
    """Generate a random string"""
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def generate_api_key() -> str:
    """Generate an API key"""
    return f"cq_{generate_random_string(40)}"


def hash_string(s: str) -> str:
    """Hash a string using SHA-256"""
    return hashlib.sha256(s.encode()).hexdigest()


def truncate_string(s: str, max_length: int = 100) -> str:
    """Truncate a string to max length"""
    if len(s) <= max_length:
        return s
    return s[:max_length-3] + '...'


def flatten_dict(d: dict[str, Any], parent_key: str = '', sep: str = '.') -> dict[str, Any]:
    """Flatten a nested dictionary"""
    items: list[tuple[str, Any]] = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep).items())
        else:
            items.append((new_key, v))
    return dict(items)


def chunk_list(lst: list, chunk_size: int) -> list[list]:
    """Split a list into chunks"""
    return [lst[i:i + chunk_size] for i in range(0, len(lst), chunk_size)]
