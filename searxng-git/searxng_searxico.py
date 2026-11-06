# SPDX-License-Identifier: AGPL-3.0-or-later
"""Favicon resolver backed by a self-hosted `searxico`_ Cloudflare Worker.

SearXNG's built-in resolvers all hand the domains appearing in your results to a
third party (DuckDuckGo, Google, Kagi, Yandex, allesedv).  Pointing them at your
own worker instead means only the worker sees them.  The worker still proxies to
an upstream icon service, so this is indirection rather than elimination: the
upstream sees the worker, not your instance or its users.

Registered through ``[favicons.proxy.resolver_map]`` in
``/etc/searxng/favicons.toml``; no patch to SearXNG is required.  The worker's
base URL comes from ``$SEARXICO_BASE_URL`` so it can be changed with a systemd
drop-in rather than by editing a packaged file.

.. _searxico: https://github.com/Aetherinox/cfworker-searxico
"""

import os

from searx import logger
from searx import network

__all__ = ["searxico"]

logger = logger.getChild("favicons.resolvers")

BASE_URL_ENV = "SEARXICO_BASE_URL"
"""Environment variable holding the worker root, e.g.
``https://searxico.<account>.workers.dev``."""

ICON_SIZE = 32
"""Pixel size requested from the worker; SearXNG renders favicons at 32px."""


def searxico(domain: str, timeout: int) -> tuple[None | bytes, None | str]:
    """Favicon resolver for a self-hosted searxico worker."""
    base_url = (os.environ.get(BASE_URL_ENV) or "").strip().rstrip("/")
    if not base_url:
        logger.error("%s is unset - cannot resolve favicons via searxico", BASE_URL_ENV)
        return None, None

    url = f"{base_url}/{domain}/{ICON_SIZE}"
    logger.debug("fetch favicon from: %s", url)

    response = network.get(url, raise_for_httperror=False, timeout=timeout)
    if not response or response.status_code != 200:
        return None, None

    mime = response.headers.get("Content-Type")
    # the worker answers with an HTML notice when it has nothing to serve
    if not mime or not mime.startswith("image/"):
        return None, None
    return response.content, mime
