"""Provisioner dry-run and Docker argv construction (no daemon needed)."""
import subprocess

import pytest

from app.config import settings
from app.services.tenant_runtime_provisioner import TenantRuntimeProvisioner


def _config(tmp_path, tenant_id=42):
    directory = tmp_path / str(tenant_id)
    directory.mkdir(parents=True)
    (directory / "config.json").write_text("{}")


def test_dry_run_has_deterministic_plan(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "tenant_data_root", str(tmp_path))
    _config(tmp_path)
    result = TenantRuntimeProvisioner().provision(42, dry_run=True)
    assert result["container_name"] == "alphaloop-ft-42"
    assert result["suggested_port"] == 19042
    assert result["commands"][1][:3] == ["docker", "run", "-d"]
    assert "--network" in result["commands"][1]


def test_provision_requires_enabled_and_config(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "tenant_data_root", str(tmp_path))
    provisioner = TenantRuntimeProvisioner()
    with pytest.raises(FileNotFoundError):
        provisioner.provision(42, dry_run=False)
    _config(tmp_path)
    monkeypatch.setattr(settings, "tenant_runtime_provisioning_enabled", False)
    with pytest.raises(PermissionError):
        provisioner.provision(42, dry_run=False)


def test_provision_builds_argv(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "tenant_data_root", str(tmp_path))
    monkeypatch.setattr(settings, "tenant_runtime_provisioning_enabled", True)
    _config(tmp_path)
    calls = []

    class Result:
        stdout = "container-id\n"

    def fake_run(args, **kwargs):
        calls.append(args)
        return Result()

    monkeypatch.setattr(subprocess, "run", fake_run)
    result = TenantRuntimeProvisioner().provision(42, dry_run=False)
    assert result["container_id"] == "container-id"
    assert calls[0][:3] == ["docker", "rm", "-f"]
    assert calls[1][:3] == ["docker", "run", "-d"]
    assert "--pids-limit" in calls[1]

    TenantRuntimeProvisioner().stop(42)
    assert calls[-1][:3] == ["docker", "rm", "-f"]


def test_kubernetes_manifest(tmp_path, monkeypatch):
    from app.services.tenant_runtime_provisioner import (
        KubernetesTenantRuntimeProvisioner,
    )

    monkeypatch.setattr(settings, "tenant_data_root", str(tmp_path))
    monkeypatch.setattr(settings, "tenant_runtime_namespace", "alphaloop")
    _config(tmp_path, tenant_id=7)
    provisioner = KubernetesTenantRuntimeProvisioner()
    result = provisioner.dry_run(7)
    assert result["url"].endswith(":8080")
    assert "kind: Deployment" in result["manifest"]
    assert "kind: Service" in result["manifest"]
    assert "tenant: '7'" in result["manifest"] or 'tenant: "7"' in result["manifest"]


def test_kubernetes_provision_requires_enabled(tmp_path, monkeypatch):
    from app.services.tenant_runtime_provisioner import (
        KubernetesTenantRuntimeProvisioner,
    )

    monkeypatch.setattr(settings, "tenant_data_root", str(tmp_path))
    _config(tmp_path, tenant_id=7)
    monkeypatch.setattr(settings, "tenant_runtime_provisioning_enabled", False)
    with pytest.raises(PermissionError):
        KubernetesTenantRuntimeProvisioner().provision(7, dry_run=False)
