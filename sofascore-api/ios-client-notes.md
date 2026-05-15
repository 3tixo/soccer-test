# Native iOS Implementation Notes

## Recommendation

Do not build your production iOS app so it depends directly on SofaScore private endpoints from `URLSession`.

Reasons:

- Direct non-browser HTTP was blocked with `403` in testing.
- Private API shape and availability are unstable.
- App Store/network review risk is higher if you ship scraping or anti-bot workarounds in the client.
- You cannot hide private routing behavior, polling volume, or any workaround logic in a distributed app.

Safer architecture if you have permission to use the data:

```text
iOS app -> your backend -> SofaScore/private data source -> normalized API -> iOS app
```

The backend can cache, normalize responses, limit polling, hide provider-specific weirdness, and let you swap to a licensed provider later.

## URLSession Reality

Adding these headers is not enough on its own:

```text
User-Agent
Referer
Origin
Accept
Accept-Language
```

Plain requests with similar headers returned `403 Forbidden` from this machine. A Chrome-TLS client worked. Native `URLSession` has an iOS TLS/network fingerprint, so expect blocking or inconsistent behavior.

## Data Modeling Strategy

Use tolerant decoding:

- Make most fields optional.
- Store IDs as `Int64` where possible.
- Treat `status.code`, `status.type`, `winnerCode`, and score objects as nullable.
- Expect different score fields per sport: football has `period1`, `period2`, `normaltime`; tennis has set scores; basketball has quarters; baseball/cricket have innings-specific data.
- For user-facing screens, create your own normalized models rather than passing SofaScore JSON through the app.

Useful normalized models:

```swift
struct MatchSummary: Identifiable, Decodable {
    let id: Int64
    let slug: String?
    let startTimestamp: Int64?
    let status: MatchStatus
    let homeTeam: TeamSummary
    let awayTeam: TeamSummary
    let homeScore: ScoreSummary?
    let awayScore: ScoreSummary?
    let tournament: TournamentSummary?
}

struct MatchStatus: Decodable {
    let code: Int?
    let description: String?
    let type: String?
}
```

## Polling Suggestions

Be conservative:

| Data | Suggested polling |
|---|---:|
| Live event detail/incidents/statistics | 15-30 seconds |
| Live schedule list | 30-60 seconds |
| Pre-match event detail | 5-15 minutes |
| Standings / tournament metadata | 30-120 minutes |
| Player/team profile | 24 hours or cache forever with manual refresh |
| Images | Cache aggressively |

Use `ETag`/`Last-Modified` if the server provides them, but do not assume it will.

## Error Handling

Plan for:

- `403` - blocked client/fingerprint/challenge/rate limit.
- `404` - route valid but no data for this event, or route changed.
- `429` - rate limiting.
- Empty arrays for valid data not yet available.
- Different top-level keys for similar concepts.

For UI, distinguish:

```text
No data yet
Feature unavailable for this match
Network/provider blocked
Provider response changed
```

## Endpoint Use By Screen

### Scores List

```text
GET /sport/{sport}/scheduled-events/{date}
GET /sport/{sport}/events/live
GET /sport/{sport}/live-tournaments
```

### Match Detail

```text
GET /event/{eventId}
GET /event/{eventId}/incidents
GET /event/{eventId}/statistics
GET /event/{eventId}/lineups
GET /event/{eventId}/graph
GET /event/{eventId}/shotmap
GET /event/{eventId}/comments
```

### Team Page

```text
GET /team/{teamId}
GET /team/{teamId}/players
GET /team/{teamId}/events/last/{page}
GET /team/{teamId}/events/next/{page}
GET /team/{teamId}/near-events
GET /team/{teamId}/transfers
```

### Player Page

```text
GET /player/{playerId}
GET /player/{playerId}/statistics/seasons
GET /player/{playerId}/transfer-history
GET /player/{playerId}/unique-tournaments
GET /player/{playerId}/attribute-overviews
```

### League Page

```text
GET /unique-tournament/{uniqueTournamentId}
GET /unique-tournament/{uniqueTournamentId}/seasons
GET /unique-tournament/{uniqueTournamentId}/season/{seasonId}/standings/total
GET /unique-tournament/{uniqueTournamentId}/season/{seasonId}/events/last/{page}
GET /unique-tournament/{uniqueTournamentId}/season/{seasonId}/events/next/{page}
GET /unique-tournament/{uniqueTournamentId}/season/{seasonId}/top-players/overall
GET /unique-tournament/{uniqueTournamentId}/season/{seasonId}/top-teams/overall
```

### Search

```text
GET /search/all?q={query}&page={page}
GET /search/events/?q={query}&page={page}
GET /search/player-team-persons/?q={query}&page={page}
GET /search/teams/?q={query}&page={page}
GET /search/unique-tournaments/?q={query}&page={page}
```

## Images

Images are simpler than JSON routes and should be cached:

```text
GET https://img.sofascore.com/api/v1/team/{teamId}/image
GET https://img.sofascore.com/api/v1/player/{playerId}/image
GET https://img.sofascore.com/api/v1/unique-tournament/{id}/image
GET https://img.sofascore.com/api/v1/unique-tournament/{id}/image/dark
GET https://img.sofascore.com/api/v1/stage/{stageId}/image
GET https://www.sofascore.com/static/images/flags/{flag}.png
```

## Shipping Advice

If this is for a real public app, seriously consider a licensed sports-data provider for production and use this research only for prototyping. If you still proceed, keep the SofaScore integration behind a server boundary with feature flags, backoff, caching, and a provider abstraction.

