"""
Logger utility
"""
import logging
from typing import Optional


class Logger:
    def __init__(self, name: str, level: int = logging.INFO):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(level)

    def debug(self, message: str, *args, **kwargs):
        self.logger.debug(message, *args, **kwargs)

    def info(self, message: str, *args, **kwargs):
        self.logger.info(message, *args, **kwargs)

    def warning(self, message: str, *args, **kwargs):
        self.logger.warning(message, *args, **kwargs)

    def error(self, message: str, *args, **kwargs):
        self.logger.error(message, *args, **kwargs)

    def critical(self, message: str, *args, **kwargs):
        self.logger.critical(message, *args, **kwargs)

    def exception(self, message: str, *args, **kwargs):
        self.logger.exception(message, *args, **kwargs)


def get_logger(name: str, level: Optional[int] = None) -> Logger:
    """Get a logger instance"""
    return Logger(name, level or logging.INFO)
