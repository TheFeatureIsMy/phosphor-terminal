"""
URL utility functions
"""
from urllib.parse import urlencode, urlparse, parse_qs, urljoin
from typing import Optional, Dict


def build_url(base: str, path: str, params: Optional[Dict[str, str]] = None) -> str:
    """Build URL with path and parameters"""
    url = urljoin(base, path)
    if params:
        url += '?' + urlencode(params)
    return url


def get_query_params(url: str) -> Dict[str, str]:
    """Get query parameters from URL"""
    parsed = urlparse(url)
    params = parse_qs(parsed.query)
    return {k: v[0] if len(v) == 1 else v for k, v in params.items()}


def is_valid_url(url: str) -> bool:
    """Validate URL format"""
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except Exception:
        return False


def is_external_url(url: str, base_url: str) -> bool:
    """Check if URL is external"""
    parsed_url = urlparse(url)
    parsed_base = urlparse(base_url)
    return parsed_url.netloc != parsed_base.netloc


def get_domain(url: str) -> Optional[str]:
    """Extract domain from URL"""
    try:
        parsed = urlparse(url)
        return parsed.netloc
    except Exception:
        return None


def get_path(url: str) -> str:
    """Extract path from URL"""
    parsed = urlparse(url)
    return parsed.path


def normalize_url(url: str) -> str:
    """Normalize URL"""
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    return url
