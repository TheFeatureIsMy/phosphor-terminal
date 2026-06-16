"""Auto-registers all category sub-packages on import."""

import logging

logger = logging.getLogger(__name__)


def register_all() -> None:
    _categories = ("llm", "cex", "dex", "notification", "market_data", "onchain", "social", "news")
    for _cat in _categories:
        try:
            __import__(f"app.services.providers.categories.{_cat}", fromlist=["_"])
        except ImportError:
            logger.debug("Category package not yet created: %s", _cat)
