"""
Input validation utilities
"""
import re
from typing import Any


def validate_email(email: str) -> bool:
    """Validate email format"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_username(username: str) -> tuple[bool, str]:
    """Validate username format"""
    if len(username) < 3:
        return False, "用户名至少3个字符"
    if len(username) > 50:
        return False, "用户名最多50个字符"
    if not re.match(r'^[a-zA-Z0-9_]+$', username):
        return False, "用户名只能包含字母、数字和下划线"
    return True, ""


def validate_password(password: str) -> tuple[bool, str]:
    """Validate password strength"""
    if len(password) < 6:
        return False, "密码至少6个字符"
    if len(password) > 128:
        return False, "密码最多128个字符"
    return True, ""


def sanitize_string(value: str, max_length: int = 1000) -> str:
    """Sanitize string input"""
    return value.strip()[:max_length]


def validate_pagination(page: int, page_size: int) -> tuple[int, int]:
    """Validate and normalize pagination parameters"""
    page = max(1, page)
    page_size = min(max(1, page_size), 100)
    return page, page_size
