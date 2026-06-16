"""Tests for the Email (SMTP) notification adapter."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.notification.email import EmailProvider


@pytest.mark.asyncio
async def test_login_success_returns_active():
    a = EmailProvider()
    fake_smtp = MagicMock()
    with patch("app.services.providers.categories.notification.email.smtplib.SMTP") as SMTP:
        SMTP.return_value.__enter__.return_value = fake_smtp
        r = await a.test_connection(
            {"username": "u", "password": "p"},
            {"host": "smtp.example.com", "port": 587, "use_tls": True, "timeout_s": 5.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE
    assert fake_smtp.login.called


@pytest.mark.asyncio
async def test_login_failure_returns_error():
    a = EmailProvider()
    with patch("app.services.providers.categories.notification.email.smtplib.SMTP") as SMTP:
        SMTP.return_value.__enter__.side_effect = Exception("auth failed")
        r = await a.test_connection(
            {"username": "u", "password": "bad"},
            {"host": "smtp.example.com", "port": 587, "use_tls": True, "timeout_s": 5.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = EmailProvider()
    assert a.provider_name == "email"
    assert a.category == ProviderCategory.NOTIFICATION
    assert a.is_multi_instance is False
