"""Minimal SMTP invite emails. Silently disabled when SMTP is not configured."""
from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage

from app.config import settings

logger = logging.getLogger(__name__)


class EmailService:
    @property
    def configured(self) -> bool:
        return bool(settings.smtp_host and settings.smtp_from)

    def send_invite(self, *, to: str, link: str, tenant_name: str) -> bool:
        return self._send(
            to=to,
            subject=f"Join {tenant_name} on AlphaLoop",
            body=(
                f"You have been invited to join {tenant_name} on AlphaLoop.\n\n"
                f"Accept the invitation: {link}\n\n"
                "If you did not expect this, ignore the email."
            ),
            label="invite",
        )

    def send_quota_warning(
        self, *, to: str, tenant_name: str, resource: str, used: int, limit: int,
    ) -> bool:
        return self._send(
            to=to,
            subject=f"{tenant_name}: {resource} usage is near its limit",
            body=(
                f"Your tenant {tenant_name} is using {used} of {limit} {resource}.\n\n"
                "Review usage in Settings -> Tenant. Existing limits still apply."
            ),
            label="quota warning",
        )

    def send_payment_failed(
        self, *, to: str, tenant_name: str, plan: str,
    ) -> bool:
        return self._send(
            to=to,
            subject=f"{tenant_name}: payment failed",
            body=(
                f"We could not process the payment for {tenant_name} ({plan}).\n\n"
                "Update the payment method to avoid losing access after the grace period."
            ),
            label="payment failed",
        )

    def send_renewal_reminder(
        self, *, to: str, tenant_name: str, plan: str, period_end: str,
    ) -> bool:
        return self._send(
            to=to,
            subject=f"{tenant_name}: subscription renews on {period_end}",
            body=(
                f"Your {plan} plan for {tenant_name} renews on {period_end}.\n\n"
                "Review billing in Settings -> Tenant."
            ),
            label="renewal reminder",
        )

    def _send(self, *, to: str, subject: str, body: str, label: str) -> bool:
        if not self.configured:
            return False
        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = settings.smtp_from
        message["To"] = to
        message.set_content(body)
        try:
            with smtplib.SMTP(
                settings.smtp_host, settings.smtp_port, timeout=10,
            ) as smtp:
                smtp.ehlo()
                if settings.smtp_use_tls:
                    smtp.starttls()
                    smtp.ehlo()
                if settings.smtp_username:
                    smtp.login(settings.smtp_username, settings.smtp_password)
                smtp.send_message(message)
            return True
        except Exception:
            logger.exception("failed to send %s email to %s", label, to)
            return False
