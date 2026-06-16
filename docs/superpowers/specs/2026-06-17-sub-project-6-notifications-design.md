---
title: Sub-project 6 — Notification Provider Real Implementations (Discord/Email/Webhook)
status: approved
date: 2026-06-17
authors: claude (brainstorming skill)
related:
  - docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md
  - docs/integrations/api-audit.md
---

# Sub-project 6 — Notification Provider Real Implementations

## 1. Problem

After sub-project 1, 3 notification providers are stubs: Discord, Email (SMTP), Webhook. Telegram is already real. This sub-project implements real `test_connection` for all 3.

## 2. Goals

1. Implement 3 real notification adapters. Each "test" verifies the delivery path is functional.
2. No new dependencies (smtplib is in stdlib; aiohttp already a dep).
3. Update `docs/integrations/api-audit.md` Notification section.

## 3. Non-Goals

- Implementing `send_notification()` (the actual delivery). The ProviderAdapter protocol only has `test_connection`. Future sub-projects add a notification dispatcher.
- OAuth2 flows for Discord bot. The webhook model is simpler.

## 4. Provider-Specific Reference

### 4.1 DiscordProvider (Webhook URL)

- **Auth:** None (Discord webhook URLs are self-authenticating)
- **Health check:** `HEAD https://discord.com/api/webhooks/{id}/{token}` — Discord returns 204 if valid, 404 if deleted
- **Credentials dict shape:** `{"webhook_url": "https://discord.com/api/webhooks/..."}`
- **Config:** `DiscordConfig { webhook_id, webhook_token, timeout_s }` (parsed from URL)

### 4.2 EmailProvider (SMTP)

- **Auth:** username + password (or none for unauthenticated SMTP)
- **Health check:** Connect to SMTP server, optionally start TLS, login, run QUIT
- **Credentials dict shape:** `{"username": "...", "password": "..."}`
- **Config:** `EmailConfig { host, port, use_tls (bool), timeout_s }`

### 4.3 WebhookProvider (Generic HTTP POST)

- **Auth:** Optional `auth_header` (e.g., `Bearer xyz`)
- **Health check:** `POST {url} {"ping": true}` — expect 2xx
- **Credentials dict shape:** `{"auth_header": "Bearer xyz"}` (optional)
- **Config:** `WebhookConfig { url, timeout_s }`

## 5. Architecture

All 3 follow `ProviderAdapter` Protocol. Each implements `test_connection` that does the actual health check (not just a generic ping).

## 6. Data Model

**No schema changes.** `credentials` and `config` JSON fields carry provider-specific data.

## 7. Migration

**No migration.** Pure code addition.

## 8. Documentation Updates

- `docs/integrations/api-audit.md` Notification section: replace 3 stub entries.

## 9. Acceptance Criteria

- 3 new adapter files + 3 new test files
- All 9 new tests pass
- `registry.list_providers('notification')` returns 4 (telegram + 3 new)
