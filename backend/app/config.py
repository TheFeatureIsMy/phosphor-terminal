import os
from pydantic_settings import BaseSettings

PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


DEFAULT_DEV_SECRET = "pulsedesk-dev-secret-change-in-production"


class Settings(BaseSettings):
    app_env: str = "development"
    database_url: str = "postgresql://pulsedesk:pulsedesk@localhost:5432/pulsedesk"
    # Optional BYPASSRLS role for command workers / schedulers. Falls back to
    # database_url when unset (single-role development and tests).
    database_url_worker: str | None = None
    # Optional fairness cap per tenant for provider health checks (0 = no cap).
    provider_health_per_tenant_limit: int = 0
    # Root for per-tenant runtime data (config, SQLite, rules).
    tenant_data_root: str = "/data/tenants"
    tenant_runtime_health_interval_s: int = 0
    tenant_runtime_health_batch_size: int = 10
    session_ttl_days: int = 30
    session_retention_days: int = 30
    session_cleanup_interval_hours: int = 0
    public_base_url: str = "http://localhost:5173"
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: str | None = None
    smtp_from: str | None = None
    smtp_use_tls: bool = True
    tenant_runtime_provisioning_enabled: bool = False
    tenant_runtime_provider: str = "docker"
    tenant_runtime_namespace: str = "alphaloop"
    tenant_runtime_pvc: str = "alphaloop-tenant-data"
    tenant_runtime_kubectl_bin: str = "kubectl"
    tenant_runtime_docker_bin: str = "docker"
    tenant_runtime_image: str = "freqtradeorg/freqtrade:stable"
    tenant_runtime_network: str = "phosphor-terminal_default"
    tenant_runtime_cpus: str = "1.0"
    tenant_runtime_memory: str = "1g"

    redis_url: str = "redis://localhost:6379/0"
    snapshot_ttl_seconds: int = 300

    freqtrade_url: str = "http://localhost:8080"
    freqtrade_username: str = "freqtrade"
    freqtrade_password: str = "freqtrade"
    freqtrade_db_path: str = os.path.join(PROJECT_ROOT, "freqtrade", "user_data", "tradesv3.sqlite")

    cors_origins: list[str] = ["http://localhost:5173", "http://localhost:5174"]

    secret_key: str = DEFAULT_DEV_SECRET
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # Remote deployment. The default stays loopback for local use; the server
    # profile sets SERVER_HOST=0.0.0.0 behind a TLS reverse proxy.
    server_host: str = "127.0.0.1"
    server_port: int = 8000
    # Host headers accepted by TrustedHostMiddleware. Use ["*"] only behind a
    # proxy that already validates Host.
    allowed_hosts: list[str] = ["localhost", "127.0.0.1", "testserver", "test"]

    # API authentication. Disable only for local test runs; production and
    # remote deployments must keep this on.
    auth_required: bool = True
    background_loops_enabled: bool = True
    tenant_audit_retention_days: int = 365
    tenant_audit_cleanup_interval_hours: int = 24
    tenant_audit_archive_dir: str = ""
    tenant_audit_archive_s3_bucket: str = ""
    tenant_audit_archive_s3_prefix: str = "audit"
    tenant_audit_archive_s3_endpoint: str = ""
    tenant_quota_warn_interval_hours: int = 24
    tenant_quota_warn_ratio: float = 0.8
    subscription_expiry_interval_hours: int = 24
    billing_enabled: bool = False
    billing_webhook_secret: str = ""
    billing_stripe_webhook_secret: str = ""
    billing_stripe_price_pro: str = ""
    billing_stripe_price_enterprise: str = ""
    billing_grace_days: int = 3
    billing_renewal_reminder_days: int = 7
    # Open self-registration. Off by default: the first user bootstraps the
    # instance, later accounts must be created by an administrator.
    allow_public_registration: bool = False

    # Fernet key for provider credentials. Required to persist secrets; without
    # it CryptoService refuses to encrypt (fail closed) instead of writing
    # plaintext.
    pulsedesk_encryption_key: str | None = None

    rate_limit_per_minute: int = 600
    rate_limit_burst: int = 50

    # Provider health scheduler (sub-project 1 of provider foundation)
    # Command worker loop
    command_worker_poll_interval_s: float = 2.0
    command_worker_stale_recovery_s: float = 60.0
    command_worker_enabled: bool = True
    # Defer a blocked command (e.g. reconciliation in progress) instead of
    # ending the whole tick, so lower-priority commands are not starved.
    command_blocked_retry_s: float = 30.0
    # Auto-requeue timed-out commands only for idempotent command types.
    command_timeout_retry_enabled: bool = True

    # Trade sync loop
    trade_sync_interval_s: float = 15.0
    trade_sync_enabled: bool = True
    trade_sync_heartbeat_stale_s: int = 30

    # Provider health scheduler (sub-project 1 of provider foundation)
    provider_health_interval_s: int = 60
    provider_health_batch_size: int = 10
    provider_health_enabled: bool = True

    # Live small execution gate — off by default (v2.5 rollout: dry-run first).
    # When false, POST /api/trading/start-live-small returns not_enabled even if
    # the full safety gate chain approves the request.
    live_small_enabled: bool = False

    log_level: str = "INFO"
    log_format: str = "json"

    debug: bool = False

    model_config = {"env_file": ".env", "extra": "ignore"}

    def security_problems(self) -> list[str]:
        """Return configuration problems that make remote deployment unsafe."""
        problems: list[str] = []
        if self.secret_key == DEFAULT_DEV_SECRET:
            problems.append(
                "SECRET_KEY is the public development default; set a random value"
            )
        if not self.pulsedesk_encryption_key:
            problems.append(
                "PULSEDESK_ENCRYPTION_KEY is not set; provider credentials cannot be encrypted"
            )
        return problems

    @property
    def is_production(self) -> bool:
        return self.app_env.strip().lower() in {"production", "prod"}


settings = Settings()
