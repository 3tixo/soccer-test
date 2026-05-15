# SofaScore Unofficial API Research

Research date: 2026-05-15

This folder documents the private/undocumented SofaScore API as a best-effort research snapshot for a future native iOS implementation.

Important honesty note: there is no public official SofaScore API contract for these routes. They are private endpoints used by SofaScore web/mobile surfaces and community wrappers. They can change, disappear, return different shapes by sport/region, or block clients at any time. Treat this as a working map, not a guarantee.

## Files

- `endpoint-catalog.md` - grouped endpoint inventory with parameters, response hints, and sport-specific routes.
- `verification-log.md` - endpoints I actually tested from this machine on 2026-05-15, with status codes and top-level JSON keys.
- `ios-client-notes.md` - practical notes for using this from a native iOS app.
- `sources.md` - sources used and how reliable each one is.

## Base URLs

The same route family appears under two hosts:

```text
https://api.sofascore.com/api/v1
https://www.sofascore.com/api/v1
```

Image/static assets commonly use:

```text
https://img.sofascore.com/api/v1
https://www.sofascore.com/static/images/flags/{flag}.png
```

## Access Behavior Observed

Plain PowerShell `Invoke-WebRequest` requests from this machine returned `403 Forbidden` for normal API routes, even with browser-like headers.

The same routes returned `200 OK` when requested with `curl_cffi` using Chrome TLS impersonation. That means headers alone are not the full story; TLS/client fingerprinting matters.

I did not need an API key or login for the verified public sports data routes. Some community notes mention captcha/session tokens; I did not verify those because the Chrome-TLS client worked without them today.

## Most Useful iOS App Routes

For a football scores app, start with these:

```text
GET /sport/{sport}/scheduled-events/{YYYY-MM-DD}
GET /sport/{sport}/events/live
GET /event/{eventId}
GET /event/{eventId}/incidents
GET /event/{eventId}/statistics
GET /event/{eventId}/lineups
GET /event/{eventId}/shotmap
GET /event/{eventId}/graph
GET /event/{eventId}/h2h
GET /team/{teamId}
GET /team/{teamId}/players
GET /team/{teamId}/events/last/{page}
GET /team/{teamId}/events/next/{page}
GET /player/{playerId}
GET /unique-tournament/{uniqueTournamentId}/seasons
GET /unique-tournament/{uniqueTournamentId}/season/{seasonId}/standings/total
GET /search/all?q={query}
```

## Known Test IDs

These IDs were useful during testing, but they are not special constants:

```text
Barcelona teamId: 2817
Arsenal teamId: 42
Bukayo Saka playerId: 934235
Premier League uniqueTournamentId: 17
LaLiga uniqueTournamentId: 8
UEFA Champions League uniqueTournamentId: 7
Verified football eventId on 2026-05-15: 14083203
Verified event customId for H2H events: ogbsrgb
```

## Big Caveats

- This may violate SofaScore terms if used outside personal research. Check legal/ToS before shipping.
- Native `URLSession` may be blocked because of TLS fingerprinting. Do not assume requests that work in Python/browser will work from iOS.
- Response schemas are inconsistent between sports and between pre-match, live, and finished events.
- Some endpoints are data-availability dependent. A route can be valid and still return `404` for an event without that feature.
- Odds, TV, fantasy, user-account, voting, and personalized endpoints are more region/auth/state sensitive than match data.

