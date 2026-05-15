# Sources

Research date: 2026-05-15

## Primary / Strong Evidence

- Live requests to `https://api.sofascore.com/api/v1` from this machine using `curl_cffi` Chrome impersonation. Results are recorded in `verification-log.md`.
- SofaScore current web JavaScript bundle, fetched from `https://www.sofascore.com/` on 2026-05-15. I extracted route-like strings from 37 script files.

## Community Code / Documentation

- `Kirill52300/sofascore_api` / PyPI `pysofascore`: https://github.com/Kirill52300/sofascore_api and https://pypi.org/project/pysofascore/
  - Useful because it is recent and uses `curl_cffi`.
  - Its own README says the package is educational/research-oriented and not actively maintained.
- `tommhe14/sofascore-wrapper`: https://github.com/tommhe14/sofascore-wrapper
  - Useful because it has many route wrappers across sports.
  - It uses Playwright/browser requests, which matches the observed anti-bot behavior.
- `apdmatos/sofascore-api`: https://github.com/apdmatos/sofascore-api/blob/main/sofascore-api.md
  - Older/simple endpoint list. Useful for baseline routes like categories, seasons, standings, events, incidents, graph.
- Hermai schema listing: https://hermai.ai/schemas/sofascore.com
  - High-level catalog only; it confirms concepts like live events, event shotmap, event statistics, and top players but hides exact route details.

## Lower-Confidence Community Notes

- Stack Overflow examples mention:
  - `/event/{id}/lineups`
  - `/event/{id}/incidents`
  - `/event/{eventId}/player/{playerId}/statistics`
- Reddit/webscraping threads mention 403/challenge behavior and client fingerprinting. These are anecdotal, but they match my local testing.

## Reliability Labels Used In The Catalog

- `Verified` - I tested the route today and got a meaningful response.
- `Bundle` - route pattern was found in SofaScore's current web JavaScript bundle.
- `Wrapper` - route appears in community wrapper source code.
- `Community` - route appears in community docs/posts but was not independently verified.
- `Availability-dependent` - route exists or appears valid, but may return 404 for events without that feature.

