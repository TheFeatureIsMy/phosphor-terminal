from __future__ import annotations

import ast


BLOCKED_IMPORTS = {"os", "subprocess", "socket", "shutil", "pathlib"}
BLOCKED_CALLS = {"eval", "exec", "compile", "open", "__import__"}


def scan_strategy_code(code: str) -> dict:
    findings: list[dict] = []
    try:
        tree = ast.parse(code)
    except SyntaxError as exc:
        return {
            "status": "failed",
            "findings": [{"severity": "critical", "message": f"Syntax error: {exc.msg}"}],
        }

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                root = alias.name.split(".")[0]
                if root in BLOCKED_IMPORTS:
                    findings.append({"severity": "critical", "message": f"Blocked import: {alias.name}"})
        elif isinstance(node, ast.ImportFrom):
            root = (node.module or "").split(".")[0]
            if root in BLOCKED_IMPORTS:
                findings.append({"severity": "critical", "message": f"Blocked import: {node.module}"})
        elif isinstance(node, ast.Call):
            name = None
            if isinstance(node.func, ast.Name):
                name = node.func.id
            elif isinstance(node.func, ast.Attribute):
                name = node.func.attr
            if name in BLOCKED_CALLS:
                findings.append({"severity": "critical", "message": f"Blocked call: {name}"})

    status = "passed" if not findings else "failed"
    return {"status": status, "findings": findings}
