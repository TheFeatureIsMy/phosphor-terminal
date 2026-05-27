"""
Date utility functions
"""
from datetime import datetime, timedelta, timezone
from typing import Optional


def utcnow() -> datetime:
    """Get current UTC time"""
    return datetime.now(timezone.utc)


def today() -> str:
    """Get today's date as string"""
    return utcnow().strftime('%Y-%m-%d')


def add_days(dt: datetime, days: int) -> datetime:
    """Add days to datetime"""
    return dt + timedelta(days=days)


def add_hours(dt: datetime, hours: int) -> datetime:
    """Add hours to datetime"""
    return dt + timedelta(hours=hours)


def diff_days(dt1: datetime, dt2: datetime) -> int:
    """Calculate difference in days"""
    return abs((dt2 - dt1).days)


def diff_hours(dt1: datetime, dt2: datetime) -> int:
    """Calculate difference in hours"""
    diff = abs((dt2 - dt1))
    return int(diff.total_seconds() / 3600)


def is_today(dt: datetime) -> bool:
    """Check if datetime is today"""
    return dt.date() == utcnow().date()


def is_yesterday(dt: datetime) -> bool:
    """Check if datetime is yesterday"""
    yesterday = utcnow().date() - timedelta(days=1)
    return dt.date() == yesterday


def format_date(dt: datetime, fmt: str = '%Y-%m-%d') -> str:
    """Format datetime to string"""
    return dt.strftime(fmt)


def format_datetime(dt: datetime) -> str:
    """Format datetime to string with time"""
    return dt.strftime('%Y-%m-%d %H:%M:%S')


def parse_date(s: str, fmt: str = '%Y-%m-%d') -> Optional[datetime]:
    """Parse date string"""
    try:
        return datetime.strptime(s, fmt)
    except ValueError:
        return None


def get_relative_time(dt: datetime) -> str:
    """Get relative time string"""
    now = utcnow()
    diff = now - dt
    seconds = int(diff.total_seconds())

    if seconds < 60:
        return '刚刚'
    if seconds < 3600:
        return f'{seconds // 60}分钟前'
    if seconds < 86400:
        return f'{seconds // 3600}小时前'
    if seconds < 604800:
        return f'{seconds // 86400}天前'
    return format_date(dt)
