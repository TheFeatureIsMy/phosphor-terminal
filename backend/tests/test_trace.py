"""Trace router must not embed credentials."""
import base64

from app.config import settings
from app.routers.trace import _ft_headers, _ft_url


def test_ft_headers_use_settings_credentials(monkeypatch):
    monkeypatch.setattr(settings, "freqtrade_username", "user1")
    monkeypatch.setattr(settings, "freqtrade_password", "pass1")

    header = _ft_headers()["Authorization"]
    assert header.startswith("Basic ")
    decoded = base64.b64decode(header.split(" ", 1)[1]).decode()
    assert decoded == "user1:pass1"


def test_ft_url_uses_configured_base(monkeypatch):
    monkeypatch.setattr(settings, "freqtrade_url", "http://ft:8080/")
    assert _ft_url("/api/v1/count") == "http://ft:8080/api/v1/count"
