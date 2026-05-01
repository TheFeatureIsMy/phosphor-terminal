"""Freqtrade launcher with ThreadedResolver fix for Windows aiodns issues."""
import sys
import aiohttp.resolver

# Force aiohttp to use ThreadedResolver instead of aiodns
# aiodns (c-ares) fails on some Windows configurations
aiohttp.resolver.DefaultResolver = aiohttp.resolver.ThreadedResolver

from freqtrade.main import main

if __name__ == "__main__":
    sys.exit(main())
