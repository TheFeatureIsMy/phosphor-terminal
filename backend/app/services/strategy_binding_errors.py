"""StrategyBinding service exception classes."""
from __future__ import annotations


class BindingError(Exception):
    code: str = "BINDING_ERROR"


class DuplicateBindingError(BindingError):
    code = "BINDING_DUPLICATE"


class PoolMismatchError(BindingError):
    code = "BINDING_POOL_MISMATCH"


class PolicyArchivedError(BindingError):
    code = "BINDING_POLICY_ARCHIVED"


class BindingInUseError(BindingError):
    code = "BINDING_IN_USE"
