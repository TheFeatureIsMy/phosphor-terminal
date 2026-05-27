"""
String utility functions
"""
import re
from typing import Optional


def capitalize(s: str) -> str:
    """Capitalize first letter"""
    return s[0].upper() + s[1:] if s else s


def camel_case(s: str) -> str:
    """Convert to camelCase"""
    words = re.split(r'[\s\-_]+', s)
    if not words:
        return s
    return words[0].lower() + ''.join(w.capitalize() for w in words[1:])


def snake_case(s: str) -> str:
    """Convert to snake_case"""
    s = re.sub(r'([A-Z])', r'_\1', s).lower()
    s = re.sub(r'[\s\-]+', '_', s)
    return s.strip('_')


def kebab_case(s: str) -> str:
    """Convert to kebab-case"""
    s = re.sub(r'([A-Z])', r'-\1', s).lower()
    s = re.sub(r'[\s_]+', '-', s)
    return s.strip('-')


def truncate(s: str, length: int, suffix: str = '...') -> str:
    """Truncate string to length"""
    if len(s) <= length:
        return s
    return s[:length - len(suffix)] + suffix


def strip_html(html: str) -> str:
    """Remove HTML tags"""
    return re.sub(r'<[^>]*>', '', html)


def escape_regex(s: str) -> str:
    """Escape regex special characters"""
    return re.escape(s)


def pluralize(count: int, singular: str, plural: Optional[str] = None) -> str:
    """Pluralize word based on count"""
    return singular if count == 1 else (plural or singular + 's')


def is_valid_email(email: str) -> bool:
    """Validate email format"""
    return bool(re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email))


def is_valid_url(url: str) -> bool:
    """Validate URL format"""
    return bool(re.match(r'^https?://', url))
