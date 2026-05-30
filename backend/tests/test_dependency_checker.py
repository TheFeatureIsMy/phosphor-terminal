import pytest
from app.services.dependency_checker import check_all_dependencies


def test_check_all_dependencies_returns_required_structure():
    result = check_all_dependencies()
    assert "required" in result
    assert "core_optional" in result
    assert "ml_models" in result
    assert "external_services" in result
    assert "readiness_score" in result
    assert isinstance(result["readiness_score"], float)
    assert 0.0 <= result["readiness_score"] <= 1.0


def test_database_always_ok():
    result = check_all_dependencies()
    assert result["required"]["database"]["status"] == "ok"


def test_core_optional_has_expected_keys():
    result = check_all_dependencies()
    for key in ["ccxt", "lightgbm", "transformers", "torch"]:
        assert key in result["core_optional"]
        assert "status" in result["core_optional"][key]
        assert result["core_optional"][key]["status"] in ("installed", "not_installed")


def test_external_services_has_expected_keys():
    result = check_all_dependencies()
    for key in ["freqtrade_api", "ollama", "openai", "anthropic", "telegram"]:
        assert key in result["external_services"]
