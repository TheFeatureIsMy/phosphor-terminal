"""Make Python HTTPS use the macOS trust store.

This machine's intercept certificate is trusted by curl and the system
keychain. Python's default bundle does not include it, so aiohttp fails
with CERTIFICATE_VERIFY_FAILED before any request leaves the machine.
"""
from __future__ import annotations

import os
import ssl
import subprocess
import sys
from pathlib import Path

_BUNDLE = Path.home() / ".local" / "share" / "pulsedesk" / "system-trust.pem"


def ensure_system_trust() -> None:
    """Point SSL_CERT_FILE at the system roots plus the login keychain."""
    if os.environ.get("SSL_CERT_FILE"):
        return
    if sys.platform != "darwin":
        return
    if not _BUNDLE.exists():
        pem = _export_keychains()
        if "BEGIN CERTIFICATE" not in pem:
            return
        _BUNDLE.parent.mkdir(parents=True, exist_ok=True)
        _BUNDLE.write_text(pem, encoding="utf-8")
    os.environ["SSL_CERT_FILE"] = str(_BUNDLE)


def client_ssl_context() -> ssl.SSLContext:
    """A verify context that includes the system trust bundle.

    aiohttp may cache the default context at import time, so callers that
    already imported aiohttp must pass this context explicitly.
    """
    ensure_system_trust()
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.check_hostname = True
    context.verify_mode = ssl.CERT_REQUIRED
    cafile = os.environ.get("SSL_CERT_FILE")
    if cafile:
        context.load_verify_locations(cafile)
    else:
        context.load_default_certs()
    return context


def _export_keychains() -> str:
    chunks: list[str] = []
    for path in (
        "/System/Library/Keychains/SystemRootCertificates.keychain",
        "/Library/Keychains/System.keychain",
        str(Path.home() / "Library/Keychains/login.keychain-db"),
    ):
        if not Path(path).exists():
            continue
        try:
            chunks.append(
                subprocess.check_output(
                    ["security", "find-certificate", "-a", "-p", path],
                    text=True,
                )
            )
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
    return "\n".join(chunks)
