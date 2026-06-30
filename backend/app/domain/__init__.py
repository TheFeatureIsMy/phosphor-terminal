"""
PulseDesk v2.5 Domain Models — ORM 定义按模块拆分。
字段将在 Phase 01 按 10_Database_ERD_v2_5.md 填充。

Submodules are imported explicitly where needed (e.g. app.database
imports ORM models for Base.metadata registration). This package init
stays side-effect-free so pure-domain modules (e.g. dsl.py) can be
imported in lightweight runtimes like the Freqtrade strategy container
without pulling SQLAlchemy.
"""
