"""Notification provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.notification.telegram import TelegramProvider
from app.services.providers.categories.notification.discord import DiscordProvider
from app.services.providers.categories.notification.email import EmailProvider
from app.services.providers.categories.notification.webhook import WebhookProvider


for _cls in (TelegramProvider, DiscordProvider, EmailProvider, WebhookProvider):
    registry.register(_cls)
