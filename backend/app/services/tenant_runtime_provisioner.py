"""Provision/stop tenant Freqtrade containers (Docker CLI or Kubernetes).

Disabled by default (`TENANT_RUNTIME_PROVISIONING_ENABLED`). Commands use fixed
argv lists or generated manifests; no shell interpolation.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

import yaml

from app.config import settings


class TenantRuntimeProvisioner:
    """Docker CLI implementation (single runtime host)."""

    def plan(self, tenant_id: int) -> dict:
        root = Path(settings.tenant_data_root).resolve()
        directory = (root / str(tenant_id)).resolve()
        if not directory.is_relative_to(root):
            raise ValueError("invalid tenant data directory")
        return {
            "tenant_id": tenant_id,
            "container_name": f"alphaloop-ft-{tenant_id}",
            "data_dir": str(directory),
            "config_path": str(directory / "config.json"),
            "suggested_port": 19000 + tenant_id,
            "image": settings.tenant_runtime_image,
            "network": settings.tenant_runtime_network,
            "volume": f"{directory}:/freqtrade/user_data",
        }

    def _run_command(self, plan: dict) -> list[str]:
        return [
            settings.tenant_runtime_docker_bin, "run", "-d",
            "--name", plan["container_name"],
            "--network", plan["network"],
            "--restart", "unless-stopped",
            "--cpus", settings.tenant_runtime_cpus,
            "--memory", settings.tenant_runtime_memory,
            "--pids-limit", "256",
            "-v", plan["volume"],
            "-e", "FREQTRADE__API_SERVER__LISTEN_IP=0.0.0.0",
            "-e", "FREQTRADE__API_SERVER__LISTEN_PORT=8080",
            plan["image"], "trade", "--config", "/freqtrade/user_data/config.json",
        ]

    def dry_run(self, tenant_id: int) -> dict:
        plan = self.plan(tenant_id)
        return {
            **plan,
            "dry_run": True,
            "commands": [
                [settings.tenant_runtime_docker_bin, "rm", "-f", plan["container_name"]],
                self._run_command(plan),
            ],
        }

    def provision(self, tenant_id: int, dry_run: bool = True) -> dict:
        plan = self.plan(tenant_id)
        if not Path(plan["config_path"]).is_file():
            raise FileNotFoundError("render/write config before provisioning")
        if dry_run:
            return self.dry_run(tenant_id)
        if not settings.tenant_runtime_provisioning_enabled:
            raise PermissionError("tenant runtime provisioning is disabled")

        subprocess.run(
            [settings.tenant_runtime_docker_bin, "rm", "-f", plan["container_name"]],
            capture_output=True, text=True, timeout=60, check=False,
        )
        result = subprocess.run(
            self._run_command(plan),
            capture_output=True, text=True, timeout=180, check=True,
        )
        return {**plan, "dry_run": False, "container_id": result.stdout.strip()}

    def stop(self, tenant_id: int) -> dict:
        if not settings.tenant_runtime_provisioning_enabled:
            raise PermissionError("tenant runtime provisioning is disabled")
        name = f"alphaloop-ft-{tenant_id}"
        subprocess.run(
            [settings.tenant_runtime_docker_bin, "rm", "-f", name],
            capture_output=True, text=True, timeout=60, check=False,
        )
        return {"tenant_id": tenant_id, "container_name": name, "stopped": True}


class KubernetesTenantRuntimeProvisioner:
    """Kubernetes implementation using generated Deployment/Service manifests."""

    def plan(self, tenant_id: int) -> dict:
        name = f"alphaloop-ft-{tenant_id}"
        return {
            "tenant_id": tenant_id,
            "container_name": name,
            "namespace": settings.tenant_runtime_namespace,
            "pvc": settings.tenant_runtime_pvc,
            "config_path": f"/var/lib/alphaloop/tenants/{tenant_id}/config.json",
            "url": f"http://{name}.{settings.tenant_runtime_namespace}.svc:8080",
            "image": settings.tenant_runtime_image,
        }

    def manifests(self, tenant_id: int) -> list[dict]:
        plan = self.plan(tenant_id)
        labels = {"app": plan["container_name"], "tenant": str(tenant_id)}
        deployment = {
            "apiVersion": "apps/v1",
            "kind": "Deployment",
            "metadata": {"name": plan["container_name"], "namespace": plan["namespace"], "labels": labels},
            "spec": {
                "replicas": 1,
                "selector": {"matchLabels": {"app": plan["container_name"]}},
                "template": {
                    "metadata": {"labels": labels},
                    "spec": {
                        "containers": [{
                            "name": "freqtrade",
                            "image": plan["image"],
                            "command": ["trade", "--config", "/freqtrade/user_data/config.json"],
                            "ports": [{"containerPort": 8080, "name": "api"}],
                            "env": [
                                {"name": "FREQTRADE__API_SERVER__LISTEN_IP", "value": "0.0.0.0"},
                                {"name": "FREQTRADE__API_SERVER__LISTEN_PORT", "value": "8080"},
                            ],
                            "volumeMounts": [{"name": "user-data", "mountPath": "/freqtrade/user_data"}],
                            "resources": {
                                "requests": {"cpu": "250m", "memory": "512Mi"},
                                "limits": {"cpu": "1", "memory": "1Gi"},
                            },
                            "securityContext": {
                                "allowPrivilegeEscalation": False,
                                "capabilities": {"drop": ["ALL"]},
                                "seccompProfile": {"type": "RuntimeDefault"},
                            },
                        }],
                        "volumes": [{
                            "name": "user-data",
                            "persistentVolumeClaim": {"claimName": plan["pvc"]},
                        }],
                    },
                },
            },
        }
        service = {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {"name": plan["container_name"], "namespace": plan["namespace"], "labels": labels},
            "spec": {
                "selector": {"app": plan["container_name"]},
                "ports": [{"name": "api", "port": 8080, "targetPort": "api"}],
            },
        }
        return [deployment, service]

    def dry_run(self, tenant_id: int) -> dict:
        return {
            **self.plan(tenant_id),
            "dry_run": True,
            "command": "kubectl apply -f -",
            "manifest": yaml.safe_dump_all(self.manifests(tenant_id), sort_keys=False),
        }

    def provision(self, tenant_id: int, dry_run: bool = True) -> dict:
        plan = self.plan(tenant_id)
        if not Path(settings.tenant_data_root, str(tenant_id), "config.json").is_file():
            raise FileNotFoundError("render/write config before provisioning")
        if dry_run:
            return self.dry_run(tenant_id)
        if not settings.tenant_runtime_provisioning_enabled:
            raise PermissionError("tenant runtime provisioning is disabled")
        manifest = yaml.safe_dump_all(self.manifests(tenant_id), sort_keys=False)
        subprocess.run(
            [settings.tenant_runtime_kubectl_bin, "apply", "-f", "-"],
            input=manifest, capture_output=True, text=True, timeout=180, check=True,
        )
        return {**plan, "dry_run": False, "applied": True}

    def stop(self, tenant_id: int) -> dict:
        if not settings.tenant_runtime_provisioning_enabled:
            raise PermissionError("tenant runtime provisioning is disabled")
        name = f"alphaloop-ft-{tenant_id}"
        subprocess.run(
            [settings.tenant_runtime_kubectl_bin, "-n", settings.tenant_runtime_namespace,
             "delete", "deployment,service", name, "--ignore-not-found"],
            capture_output=True, text=True, timeout=120, check=False,
        )
        return {"tenant_id": tenant_id, "container_name": name, "stopped": True}


def get_tenant_runtime_provisioner():
    if settings.tenant_runtime_provider == "kubernetes":
        return KubernetesTenantRuntimeProvisioner()
    return TenantRuntimeProvisioner()
