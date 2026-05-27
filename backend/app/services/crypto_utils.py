"""
Crypto utility functions
"""
import hashlib
import secrets
import base64
from typing import Optional


def sha256(message: str) -> str:
    """Calculate SHA-256 hash"""
    return hashlib.sha256(message.encode()).hexdigest()


def md5(message: str) -> str:
    """Calculate MD5 hash"""
    return hashlib.md5(message.encode()).hexdigest()


def generate_random_bytes(n: int = 32) -> bytes:
    """Generate random bytes"""
    return secrets.token_bytes(n)


def generate_random_hex(n: int = 32) -> str:
    """Generate random hex string"""
    return secrets.token_hex(n)


def generate_api_key() -> str:
    """Generate API key"""
    return f"cq_{generate_random_hex(32)}"


def base64_encode(data: bytes) -> str:
    """Base64 encode bytes"""
    return base64.b64encode(data).decode('utf-8')


def base64_decode(s: str) -> bytes:
    """Base64 decode string"""
    return base64.b64decode(s)


def constant_time_compare(a: str, b: str) -> bool:
    """Constant time string comparison"""
    return secrets.compare_digest(a.encode(), b.encode())
