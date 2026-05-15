# Endpoint Catalog

Research date: 2026-05-15

Base URL:

```text
https://api.sofascore.com/api/v1
```

Alternative host used by some wrappers:

```text
https://www.sofascore.com/api/v1
```

Placeholders:

- `{sport}`: `football`, `basketball`, `tennis`, `ice-hockey`, `table-tennis`, `baseball`, `handball`, `american-football`, `volleyball`, `darts`, `esports`, `mma`, `motorsport`, `cricket`, `rugby`, `futsal`, `waterpolo`, `snooker`, `cycling`, `badminton`, and other sport slugs found by the site.
- `{eventId}`, `{teamId}`, `{playerId}`, `{uniqueTournamentId}`, `{seasonId}`, `{categoryId}` are numeric IDs unless noted.
- `{customId}` is the event `customId`; some H2H routes accepted it during testing.
- `{providerId}` is an odds provider ID. `1` worked in tests.

Reliability labels:

- `Verified`: tested successfully on 2026-05-15.
- `Bundle`: found in current SofaScore web JS.
- `Wrapper`: found in community wrapper source.
- `Availability-dependent`: may return 404 if the feature is not available for that event/sport/region.

## Sports, Categories, Config

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/sport` | Bundle. List/metadata root for sports. |
| GET | `/sport/{sport}/categories` | Verified. Countries/regions for a sport. |
| GET | `/sport/{sport}/categories/all` | Verified. Extended category list. |
| GET | `/sport/{sport}/live-categories` | Bundle. Categories with live events. |
| GET | `/sport/{sport}/event-count` | Bundle. Count by sport/date context. |
| GET | `/sport/0/event-count` | Wrapper. Returns aggregate counts by sport. |
| GET | `/sport/{sport}/scheduled-events/{YYYY-MM-DD}` | Verified. Flat event list for date. |
| GET | `/sport/{sport}/scheduled-tournaments/{YYYY-MM-DD}/page/{page}` | Bundle. Grouped by tournament. |
| GET | `/sport/{sport}/events/live` | Verified. Live events. |
| GET | `/sport/{sport}/live-tournaments` | Verified. Live grouped by tournament. |
| GET | `/sport/{sport}/finished-upcoming-tournaments/{YYYY-MM-DD}` | Bundle. |
| GET | `/sport/{sport}/main-events/{date}` | Bundle. Main events, some sports. |
| GET | `/sport/{sport}/main-events/{date}/extended` | Wrapper for MMA variant. |
| GET | `/sport/{sport}/trending-top-players` | Bundle. |
| GET | `/sport/{sport}/odds/{providerId}/{type}` | Bundle. |
| GET | `/config/unique-tournaments/{language}/{sport}` | Community. Top/default unique tournaments by language/sport. |
| GET | `/config/top-unique-tournaments/{countryCode}/{sport}` | Bundle/Wrapper. |
| GET | `/config/default-unique-tournaments/{countryCode}/{sport}` | Wrapper. |
| GET | `/config/country-sport-priorities/country` | Bundle. |
| GET | `/config/country-sport-priorities/country/{countryCode}` | Community. |
| GET | `/config/popular-entities/{sport}` | Bundle. |
| GET | `/config/popular-entities/{sport}/{entityType}` | Bundle. |
| GET | `/config/follow-suggestions/{sport}/{id}` | Bundle. |
| GET | `/config/footer/{locale}` | Bundle. |
| GET | `/config/robots/web` | Bundle. |
| GET | `/country/alpha2` | Community. IP-derived country. |
| GET | `/country/{countryCode}/flag` | Bundle. |

## Search

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/search/all?q={query}&page={page}` | Verified without slash variant. General search. |
| GET | `/search/all/?q={query}&page={page}` | Wrapper. General search. |
| GET | `/search/events/?q={query}&page={page}` | Verified. |
| GET | `/search/player-team-persons/?q={query}&page={page}` | Verified. Players/teams/managers. |
| GET | `/search/teams/?q={query}&page={page}` | Verified. |
| GET | `/search/unique-tournaments/?q={query}&page={page}` | Verified. |
| GET | `/search/players/{query}` | Wrapper. Dedicated player search. |
| GET | `/search/players?q={query}` | Community variant. |
| GET | `/search/teams-by-sport/{sport}/{query}` | Bundle. |
| GET | `/search/suggestions/{query}` | Bundle. |
| GET | `/search/unique-tournaments-editor/{query}` | Bundle. |
| GET | `/search/unique-tournaments-with-cuptree/{query}` | Bundle. |
| GET | `/search/unique-tournaments-with-power-rankings/{query}` | Bundle. |
| GET | `/search/unique-tournaments-with-sps/{query}` | Bundle. |
| GET | `/search/unique-tournaments-with-standings/{query}` | Bundle. |
| GET | `/search/unique-tournaments-with-totw/{query}` | Bundle. |

## Categories

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/category/{categoryId}/unique-tournaments` | Verified. Returns `groups`. |
| GET | `/category/{categoryId}/unique-stages` | Bundle. Motorsport/stage sports. |
| GET | `/category/{categoryId}/scheduled-events/{YYYY-MM-DD}` | Bundle. |
| GET | `/category/{categoryId}/live-unique-tournaments` | Bundle. |
| GET | `/category/{categoryId}/{sport}/{date}/unique-tournament-event-count` | Bundle pattern. |
| GET | `/category/{categoryId}/image` | Bundle. |

## Unique Tournaments / Leagues

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/unique-tournament/{uniqueTournamentId}` | Verified. Tournament details. |
| GET | `/unique-tournament/{uniqueTournamentId}/seasons` | Verified. |
| GET | `/unique-tournament/{uniqueTournamentId}/scheduled-events/{YYYY-MM-DD}` | Community/Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/events-on-date?date={YYYY-MM-DD}` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/events/live/{page}` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/featured-events` | Bundle/Wrapper. |
| GET | `/unique-tournament/{uniqueTournamentId}/recent-event-ids` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/media` | Wrapper/Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/meta` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/player-news` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/summary` | Wrapper, MMA. |
| GET | `/unique-tournament/{uniqueTournamentId}/winners` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/top-player-performance` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/main-events/{date}/{page}` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/scheduled-mma-main-events/{date}` | Wrapper/Bundle, MMA. |
| GET | `/unique-tournament/{uniqueTournamentId}/tournament/{tournamentId}/mma-events/{page}` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/player-transfer-history/{page}/{type}` | Bundle. |
| GET | `/unique-tournament/{uniqueTournamentId}/player-votes/ranking` | Bundle. |
| POST | `/unique-tournament/{uniqueTournamentId}/player-votes/vote` | Bundle. Mutating/user action. |
| GET | `/unique-tournament/{uniqueTournamentId}/image` | Bundle/Image. |
| GET | `/unique-tournament/{uniqueTournamentId}/image/dark` | Wrapper/Image. |

## Tournament Season Routes

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/unique-tournament/{id}/season/{seasonId}/info` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/rounds` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/round/{round}` | Wrapper. |
| GET | `/unique-tournament/{id}/season/{seasonId}/events/round/{round}` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/events/round/{round}/slug/round-{round}` | Wrapper. |
| GET | `/unique-tournament/{id}/season/{seasonId}/events/last/{page}` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/events/next/{page}` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/events` | Wrapper, eSports. |
| GET | `/unique-tournament/{id}/season/{seasonId}/standings/total` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/standings/home` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/standings/away` | Verified. |
| GET | `/tournament/{tournamentId}/season/{seasonId}/standings/total` | Wrapper. Non-unique tournament variant. |
| GET | `/unique-tournament/{id}/season/{seasonId}/cuptrees` | Wrapper/Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/cuptrees/structured` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/groups` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/divisions` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/teams` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/team-events/{type}` | Wrapper/Bundle. Example `total`. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-players/overall` | Verified. Large response. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-players/{statType}` | Bundle. `goals` returned 404 in one test; use available `statisticsType`/site behavior. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-players-per-game/{scope}/{statType}` | Verified with `all/overall`. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-teams/overall` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-teams/{statType}` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-ratings/{statType}` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-followed-players` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-followed-teams` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/trending-top-players` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/team-of-the-week/rounds` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/team-of-the-week/{round}` | Wrapper/Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/team-of-the-week/periods` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/team-of-the-season` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/player-of-the-season` | Wrapper/Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/player-of-the-season-race` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/statistics/info` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/statistics?{query}` | Bundle. Paginated/filtered stats. |
| GET | `/unique-tournament/{id}/season/{seasonId}/{kind}-statistics/types` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/shot-action-areas/{type}` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/power-rankings/rounds` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/power-rankings/round/{round}` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/venues` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/venue/{venueId}/events/{direction}/{page}` | Bundle. |
| GET | `/unique-tournament/{id}/season/{seasonId}/team/{teamId}/team-performance-graph-data` | Verified via Barcelona/PL-like route. |
| GET | `/unique-tournament/{id}/season/{seasonId}/draft` | Bundle. Draft sports. |
| GET | `/unique-tournament/{id}/draft/{draftId}/pick-lottery-probability` | Bundle. |
| GET | `/unique-tournament/{id}/draft/{draftId}/pick/{pickId}` | Bundle. |
| GET | `/unique-tournament/{id}/draft/{draftId}/prospect/{prospectId}` | Bundle. |

## Events / Matches

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/event/{eventId}` | Verified. Full event. |
| GET | `/event/{eventId}/meta` | Bundle. |
| GET | `/event/{eventId}/currently-relevant` | Bundle. |
| GET | `/event/newly-added-events` | Community/Bundle. |
| GET | `/event/popular-live-stream/{sport}` | Bundle. |
| GET | `/event/{eventId}/incidents` | Verified. Goals/cards/subs/VAR/etc. |
| GET | `/event/{eventId}/statistics` | Verified. Match stats by period/group. |
| GET | `/event/{eventId}/lineups` | Verified. Formations, starters, subs, ratings. |
| GET | `/event/{eventId}/managers` | Verified. |
| GET | `/event/{eventId}/average-positions` | Verified. |
| GET | `/event/{eventId}/graph` | Verified. Momentum graph. |
| GET | `/event/{eventId}/graph/sequence` | Bundle. |
| GET | `/event/{eventId}/graph/win-probability` | Availability-dependent; 404 in one test. |
| GET | `/event/{eventId}/live-match-tracker` | Bundle. |
| GET | `/event/{eventId}/live-match-tracker/{language}/invert-teams/{bool}` | Bundle. |
| GET | `/event/{eventId}/live-action-widget` | Bundle. |
| GET | `/event/{eventId}/shotmap` | Verified. Shots, xG, xGOT, coordinates. |
| GET | `/event/{eventId}/shotmap/{teamId}` | Availability-dependent; 404 in one test. |
| GET | `/event/{eventId}/shotmap/player/{playerId}` | Bundle. |
| GET | `/event/{eventId}/player/{playerId}/shotmap` | Bundle/Community. |
| GET | `/event/{eventId}/heatmap/{teamId}` | Verified. Team heatmap. |
| GET | `/event/{eventId}/player/{playerId}/heatmap` | Bundle/Community. |
| GET | `/event/{eventId}/player/{playerId}/statistics` | Bundle/Community. |
| GET | `/event/{eventId}/player/{playerId}/rating-breakdown` | Bundle. |
| GET | `/event/{eventId}/goalkeeper-shotmap/player/{playerId}` | Bundle. |
| GET | `/event/{eventId}/jersey/{teamId}/player` | Bundle. |
| GET | `/event/{eventId}/jersey/{teamId}/goalkeeper` | Bundle. |
| GET | `/event/{eventId}/h2h` | Verified. Team/manager duel summary. |
| GET | `/event/{eventId}/h2h/events` | Bundle. |
| GET | `/event/{customId}/h2h/events` | Verified with custom ID. Large H2H event list. |
| GET | `/event/{eventId}/best-players` | Bundle. |
| GET | `/event/{eventId}/best-players/summary` | Verified. |
| GET | `/event/{eventId}/pregame-form` | Verified. |
| GET | `/event/{eventId}/team-streaks` | Verified. |
| GET | `/event/{eventId}/team-streaks/betting-odds/{providerId}` | Bundle. |
| GET | `/event/{eventId}/votes` | Verified. |
| POST | `/event/{eventId}/vote` | Bundle. Mutating/user action. |
| POST | `/event/{eventId}/change-vote` | Bundle. Mutating/user action. |
| GET | `/event/{eventId}/comments` | Verified. Commentary. |
| GET | `/event/{eventId}/highlights` | Verified. |
| GET | `/event/{eventId}/sport-video-highlights/country/{countryCode}/extended` | Bundle/Community. |
| GET | `/event/{eventId}/media/news` | Bundle. |
| GET | `/event/{eventId}/media/summary/country/{countryCode}` | Bundle/Community. |
| GET | `/event/{eventId}/official-tweets` | Bundle/Community. |
| GET | `/event/{eventId}/tweets` | Bundle. |
| GET | `/event/{eventId}/weather` | Bundle. |
| GET | `/event/{eventId}/ai-insights/{lang}` | Bundle. |
| GET | `/event/{eventId}/ai-insights-postmatch/{lang}` | Bundle/Community. |
| GET | `/event/{eventId}/fantasy` | Not observed; use `/fantasy/event/{eventId}`. |
| GET | `/fantasy/event/{eventId}` | Verified. |

## Event Odds, TV, Media

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/event/{eventId}/odds/{providerId}/featured` | Verified. |
| GET | `/event/{eventId}/odds/{providerId}/all` | Verified. |
| GET | `/event/{eventId}/odds/{providerId}/additional` | Bundle. |
| GET | `/event/{eventId}/odds/{providerId}/boost` | Bundle/Community. |
| GET | `/event/{eventId}/odds/{providerId}/changes` | Bundle. |
| GET | `/event/{eventId}/provider/{providerId}/winning-odds` | Verified. |
| GET | `/odds/providers/{countryCode}/web` | Verified. |
| GET | `/odds/providers/{countryCode}/web-odds` | Community. |
| GET | `/odds/providers/{countryCode}/web-featured` | Community. |
| GET | `/odds/{providerId}/featured-events/{sport}` | Bundle/Community. |
| GET | `/odds/{providerId}/featured-events-by-popularity/{sport}` | Bundle/Community. |
| GET | `/odds/{providerId}/featured-events-by-tiers/{sport}` | Bundle. |
| GET | `/odds/{providerId}/recommended-prematch/tournament/{tournamentId}` | Bundle. |
| GET | `/odds/{providerId}/recommended-prematch-top-voted/sport/{sport}` | Bundle. |
| GET | `/odds/{providerId}/boost/{sport}` | Bundle. |
| GET | `/odds/{providerId}/dropping/{sport}` | Bundle. |
| GET | `/odds/{providerId}/winning/{sport}` | Bundle. |
| GET | `/odds/{providerId}/top-h2h/{sport}` | Bundle. |
| GET | `/odds/{providerId}/high-value-streaks` | Bundle. |
| GET | `/odds/team/{teamId}/provider/{providerId}` | Bundle. |
| GET | `/odds/stage/{stageId}/provider/{providerId}/featured` | Bundle. |
| GET | `/odds/stage/{stageId}/provider/{providerId}/all` | Bundle. |
| GET | `/odds/provider/{providerId}/logo` | Bundle/Image. |
| GET | `/odds/top-team-streaks/{streakType}/{sport}` | Wrapper/Bundle. |
| GET | `/tv/event/{eventId}/country-channels` | Availability-dependent; 404 in one test. |
| GET | `/tv/{eventId}/{countryCode}/country-channels` | Bundle variant. |
| GET | `/tv/channel/{channelId}/event/{eventId}/votes` | Wrapper. |
| GET | `/tv/channel/{channelId}/{eventId}/{countryCode}/votes` | Bundle variant. |
| GET | `/tv/channel/{channelId}/schedule` | Wrapper/Bundle. |
| GET | `/tv/country/{countryCode}/channels` | Bundle. |
| GET | `/tv/country/{countryCode}/popular-channels` | Bundle. |
| GET | `/tv-schedule` | Bundle. |

## Football-Specific Useful Data

These are not necessarily football-only, but are most useful for football:

```text
/event/{eventId}/shotmap
/event/{eventId}/statistics
/event/{eventId}/incidents
/event/{eventId}/lineups
/event/{eventId}/average-positions
/event/{eventId}/graph
/event/{eventId}/player/{playerId}/statistics
/event/{eventId}/player/{playerId}/heatmap
/event/{eventId}/player/{playerId}/shotmap
/unique-tournament/{id}/season/{seasonId}/top-players/overall
/unique-tournament/{id}/season/{seasonId}/team-of-the-week/{round}
/unique-tournament/{id}/season/{seasonId}/player-of-the-season-race
/team/{teamId}/unique-tournament/{id}/season/{seasonId}/statistics/overall
/player/{playerId}/unique-tournament/{id}/season/{seasonId}/statistics/overall
```

## Teams

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/team/{teamId}` | Verified. |
| GET | `/team/{teamId}/players` | Verified. Squad/support staff. |
| GET | `/team/{teamId}/events/last/{page}` | Verified. |
| GET | `/team/{teamId}/events/next/{page}` | Wrapper. |
| GET | `/team/{teamId}/events` | Bundle. |
| GET | `/team/{teamId}/events/{direction}` | Bundle pattern. |
| GET | `/team/{teamId}/near-events` | Verified. |
| GET | `/team/{teamId}/featured-event` | Bundle. |
| GET | `/team/{teamId}/recent-event-ids` | Bundle. |
| GET | `/team/{teamId}/events-with-lineups` | Bundle. |
| GET | `/team/{teamId}/events-with-attack-momentum` | Bundle. |
| GET | `/team/{teamId}/performance` | Verified via tennis/team wrapper. |
| GET | `/team/{teamId}/transfers` | Verified. |
| GET | `/team/{teamId}/player-transfer-history/{page}/{type}` | Bundle. |
| GET | `/team/{teamId}/unique-tournaments` | Bundle/Community. |
| GET | `/team/{teamId}/unique-tournaments/all` | Bundle. |
| GET | `/team/{teamId}/recent-unique-tournaments` | Bundle/Wrapper. |
| GET | `/team/{teamId}/featured-players` | Bundle/Community. |
| GET | `/team/{teamId}/team-statistics/seasons` | Verified. |
| GET | `/team/{teamId}/player-statistics/seasons` | Bundle. |
| GET | `/team/{teamId}/standings/seasons` | Wrapper. |
| GET | `/team/{teamId}/unique-tournament/{id}/season/{seasonId}/statistics/{type}` | Verified with `overall`. |
| GET | `/team/{teamId}/unique-tournament/{id}/season/{seasonId}/top-players/{type}` | Verified with `overall`. |
| GET | `/team/{teamId}/unique-tournament/{id}/season/{seasonId}/player-statistics/{type}` | Wrapper/Bundle. |
| GET | `/team/{teamId}/unique-tournament/{id}/season/{seasonId}/ranks/{type}` | Bundle. |
| GET | `/team/{teamId}/unique-tournament/{id}/season/{seasonId}/goal-distributions` | Bundle. |
| GET | `/team/{teamId}/unique-tournament/{id}/events/{direction}` | Bundle. |
| GET | `/team/{teamId}/season/{seasonId}/best-result` | Bundle. |
| GET | `/team/{teamId}/year-statistics/{year}` | Bundle. |
| GET | `/team/{teamId}/achievements` | Bundle. |
| GET | `/team/{teamId}/official-tweets` | Bundle. |
| GET | `/team/{teamId}/media` | Verified. |
| GET | `/team/{teamId}/media/videos` | Bundle. |
| GET | `/team/{teamId}/media/summary/country/{countryCode}` | Bundle. |
| GET | `/team/{teamId}/rankings` | Bundle. |
| GET | `/team/{teamId}/career-statistics` | Wrapper, MMA/fighter. |
| GET | `/team/{teamId}/grand-slam/best-results` | Bundle, tennis. |
| GET | `/team/{teamId}/stage-seasons` | Wrapper/Bundle, motorsport. |
| GET | `/team/{teamId}/stage-season/{seasonId}/races` | Wrapper/Bundle, motorsport. |
| GET | `/team/{teamId}/driver-career-history` | Bundle, motorsport. |
| GET | `/team/{teamId}/image` | Image host route. |

## Players

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/player/{playerId}` | Verified. |
| GET | `/player/{playerId}/statistics` | Bundle. |
| GET | `/player/{playerId}/statistics/seasons` | Verified. |
| GET | `/player/{playerId}/statistics/match-type/{type}` | Bundle. |
| GET | `/player/{playerId}/unique-tournaments` | Verified. |
| GET | `/player/{playerId}/events/last/{page}` | Wrapper. |
| GET | `/player/{playerId}/events/next/{page}` | Community. |
| GET | `/player/{playerId}/unique-tournament/{id}/events/last/{page}` | Bundle. |
| GET | `/player/{playerId}/unique-tournament/{id}/season/{seasonId}/statistics/{type}` | Wrapper/Bundle. Use `overall` for football-style season stats. |
| GET | `/player/{playerId}/unique-tournament/{id}/statistics/{type}` | Bundle. |
| GET | `/player/{playerId}/unique-tournament/{id}/season/{seasonId}/ratings/{type}` | Bundle/Wrapper, basketball. |
| GET | `/player/{playerId}/unique-tournament/{id}/season/{seasonId}/heatmap/{type}` | Bundle. |
| GET | `/player/{playerId}/unique-tournament/{id}/season/{seasonId}/shot-actions/{type}` | Bundle/Wrapper, ice hockey. |
| GET | `/player/{playerId}/unique-tournament/{id}/season/{seasonId}/pitches/{type}/{page}` | Bundle. |
| GET | `/player/{playerId}/season/{seasonId}/statistical-rankings/{type}` | Bundle. |
| GET | `/player/{playerId}/transfer-history` | Verified. |
| GET | `/player/{playerId}/attribute-overviews` | Verified. |
| GET | `/player/{playerId}/characteristics` | Bundle/Community. |
| GET | `/player/{playerId}/national-team-statistics` | Verified. |
| GET | `/player/{playerId}/last-year-summary` | Wrapper, baseball/hockey. |
| GET | `/player/{playerId}/media` | Bundle. |
| GET | `/player/{playerId}/media/videos` | Bundle. |
| GET | `/player/{playerId}/media/summary/country/{countryCode}` | Bundle. |
| GET | `/player/{playerId}/penalty-history/unique-tournament/{id}/season/{seasonId}` | Bundle. |
| GET | `/player/{playerId}/image` | Image host route. |

## Managers

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/manager/{managerId}` | Wrapper/Bundle. |
| GET | `/manager/{managerId}/career-history` | Bundle. |
| GET | `/manager/{managerId}/events/{direction}` | Bundle. |
| GET | `/manager/{managerId}/image` | Bundle/Image. |

## Tennis

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/sport/tennis/categories` | Verified. |
| GET | `/sport/tennis/events/live` | Generic live route. |
| GET | `/config/default-unique-tournaments/{countryCode}/tennis` | Wrapper. |
| GET | `/event/{eventId}/tennis-power` | Wrapper/Bundle. |
| GET | `/event/{eventId}/point-by-point` | Wrapper/Bundle. |
| GET | `/team/{playerId}/recent-unique-tournaments` | Wrapper. Tennis players are often `team` entities. |
| GET | `/team/{playerId}/performance` | Wrapper. |
| GET | `/team/{playerId}/events/next/0` | Wrapper. |
| GET | `/team/{playerId}/events/last/0` | Wrapper. |

## Basketball / American Football / Baseball / Hockey

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/sport/basketball/events/live` | Verified. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-players/regularSeason` | Wrapper. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-teams/regularSeason` | Wrapper. |
| GET | `/unique-tournament/{id}/season/{seasonId}/top-players-per-game/all/regularSeason` | Wrapper. |
| GET | `/team/{teamId}/unique-tournament/{id}/season/{seasonId}/top-players/regularSeason` | Wrapper, hockey. |
| GET | `/team/{teamId}/unique-tournament/{id}/season/{seasonId}/top-players/playoffs` | Wrapper, American football. |
| GET | `/team/{teamId}/unique-tournament/{id}/season/{seasonId}/player-statistics/regularSeason` | Wrapper. |
| GET | `/player/{playerId}/unique-tournament/{id}/season/{seasonId}/statistics/regularSeason` | Wrapper. |
| GET | `/player/{playerId}/unique-tournament/{id}/season/{seasonId}/ratings` | Wrapper, basketball. |
| GET | `/event/{eventId}/at-bats` | Bundle, baseball. |
| GET | `/event/{eventId}/atbat/{atBatId}/pitches` | Bundle, baseball. |
| GET | `/event/{eventId}/player/{playerId}/pitches/{type}` | Bundle, baseball. |
| GET | `/event/{eventId}/series` | Bundle, baseball/playoffs. |
| GET | `/event/{eventId}/umpires` | Bundle, baseball. |

## Cricket

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/sport/cricket/categories` | Wrapper. |
| GET | `/config/default-unique-tournaments/{countryCode}/cricket` | Wrapper. |
| GET | `/event/{eventId}/innings` | Wrapper/Bundle. |

## eSports

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/sport/esports/categories` | Wrapper. |
| GET | `/sport/esports/events/live` | Wrapper. |
| GET | `/event/{eventId}/esports-games` | Wrapper/Bundle. |
| GET | `/esports-game/{gameId}/rounds` | Wrapper/Bundle. |
| GET | `/esports-game/{gameId}/lineups` | Wrapper/Bundle. |
| GET | `/esports-game/{gameId}/team-streaks` | Wrapper. |
| GET | `/esports-game/{gameId}/highlights` | Wrapper. |
| GET | `/esports-game/{gameId}/bans` | Bundle. |
| GET | `/esports-game/{gameId}/statistics` | Bundle. |

## MMA

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/sport/mma/events/live` | Verified. |
| GET | `/sport/mma/main-events/{date}/extended` | Wrapper/Bundle. |
| GET | `/unique-tournament/{organizationId}/scheduled-mma-main-events/{date}` | Wrapper. |
| GET | `/category/1708/unique-tournaments` | Wrapper. MMA organizations category. |
| GET | `/team/{fighterId}/career-statistics` | Wrapper. |
| GET | `/team/{fighterId}/events/next/0` | Wrapper. |
| GET | `/team/{fighterId}/events/last/0` | Wrapper. |
| GET | `/rankings/team/{fighterId}` | Wrapper/Bundle. |
| GET | `/rankings/{rankingId}` | Wrapper. |
| GET | `/rankings/type/{type}/featured-events` | Bundle. |
| GET | `/rankings/unique-tournament/{id}/summary` | Bundle. |
| GET | `/rankings/unique-tournament/{id}/{type}/{page}` | Bundle. |

## Motorsport / Stages

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/sport/motorsport/categories` | Verified. |
| GET | `/sport/motorsport/events/live` | Wrapper. |
| GET | `/stage/sport/motorsport/featured` | Wrapper/Bundle. |
| GET | `/stage/sport/{sport}/scheduled/{date}` | Bundle. |
| GET | `/unique-stage/{uniqueStageId}/seasons` | Wrapper/Bundle. |
| GET | `/unique-stage/{uniqueStageId}/recent-stage-ids` | Bundle. |
| GET | `/unique-stage/{uniqueStageId}/image` | Bundle/Image. |
| GET | `/stage/{stageId}` | Wrapper/Bundle. |
| GET | `/stage/{stageId}/extended` | Bundle. |
| GET | `/stage/{stageId}/substages` | Wrapper/Bundle. |
| GET | `/stage/{stageId}/substages-with-rankings` | Bundle. |
| GET | `/stage/{stageId}/standings/competitor` | Wrapper/Bundle. |
| GET | `/stage/{stageId}/standings/team` | Wrapper. |
| GET | `/stage/{stageId}/standings/{type}` | Bundle. |
| GET | `/stage/{stageId}/driver-performance` | Bundle. |
| GET | `/stage/{stageId}/races/type/{type}` | Bundle. |
| GET | `/stage/{stageId}/highlights` | Bundle. |
| GET | `/stage/{stageId}/image` | Wrapper/Image. |
| GET | `/team/{driverId}/stage-seasons` | Wrapper. |
| GET | `/team/{teamId}/stage-seasons` | Wrapper. |
| GET | `/team/{driverId}/stage-season/{seasonId}/races` | Wrapper. |
| GET | `/team/{teamId}/stage-season/{seasonId}/races` | Wrapper. |

## Calendar

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/calendar/{sport}/{year}/{month}/stages` | Bundle. |
| GET | `/calendar/{sport}/{year}/{month}/unique-tournaments` | Bundle. |
| GET | `/calendar/season/{seasonId}/{month}/days-with-events` | Bundle. |
| GET | `/calendar/unique-tournament/{uniqueTournamentId}/{page}/months-with-events` | Wrapper/Bundle. |

## Fantasy

These routes were in the web bundle. Most likely require user state/auth for anything that mutates or reads a user squad.

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/fantasy/event/{eventId}` | Verified. |
| GET | `/fantasy` | Bundle. |
| GET | `/fantasy/landing` | Bundle. |
| GET | `/fantasy/rules` | Bundle. |
| GET | `/fantasy/competition/active-competitions` | Bundle. |
| GET | `/fantasy/competition/upcoming-competitions` | Bundle. |
| GET | `/fantasy/competition/{competitionId}` | Bundle. |
| GET | `/fantasy/competition/{competitionId}/filters` | Bundle. |
| GET | `/fantasy/competition/{competitionId}/rounds` | Bundle. |
| GET | `/fantasy/competition/{competitionId}/top-players` | Bundle. |
| GET | `/fantasy/competition/{competitionId}/top-players-per-round` | Bundle. |
| GET | `/fantasy/competition/{competitionId}/fixture-difficulties/next-rounds` | Bundle. |
| GET | `/fantasy/competition/{competitionId}/{roundId}/user-age-groups` | Bundle. |
| POST | `/fantasy/competition/{competitionId}/squad/auto-select` | Bundle. Mutating/user action. |
| POST | `/fantasy/competition/{competitionId}/squad/create` | Bundle. |
| POST | `/fantasy/competition/{competitionId}/squad/update` | Bundle. |
| POST | `/fantasy/competition/{competitionId}/squad/delete` | Bundle. |
| POST | `/fantasy/competition/{competitionId}/squad/transfer` | Bundle. |
| GET | `/fantasy/round/{roundId}/filters` | Bundle. |
| GET | `/fantasy/round/{roundId}/player-statistics` | Bundle. |
| GET | `/fantasy/round/{roundId}/team-of-the-round` | Bundle. |
| POST | `/fantasy/round/{roundId}/squad/substitute` | Bundle. |
| GET | `/fantasy/player/{playerId}` | Bundle. |
| GET | `/fantasy/player/{playerId}/competitions` | Bundle. |
| GET | `/fantasy/player/{playerId}/fixtures` | Bundle. |
| GET | `/fantasy/player/{playerId}/round/{roundId}` | Bundle. |
| GET | `/fantasy/player/{playerId}/event/{eventId}/competition/{competitionId}` | Bundle. |
| GET | `/fantasy/league/{leagueId}` | Bundle. |
| GET | `/fantasy/league/{leagueId}/config` | Bundle. |
| GET | `/fantasy/league/{leagueId}/join-code` | Bundle. |
| POST | `/fantasy/league/create` | Bundle. |
| POST | `/fantasy/league/join/{code}` | Bundle. |
| POST | `/fantasy/league/join/random/{competitionId}` | Bundle. |
| POST | `/fantasy/league/{leagueId}/leave` | Bundle. |
| POST | `/fantasy/league/{leagueId}/kick` | Bundle. |
| POST | `/fantasy/league/{leagueId}/regenerate-join-code` | Bundle. |
| GET | `/fantasy/league/{leagueId}/participants?page={page}&q={query}` | Bundle. |
| GET | `/fantasy/user/{userId}/competitions` | Bundle. |
| GET | `/fantasy/user/{userId}/finished-competitions` | Bundle. |
| GET | `/fantasy/user/{userId}/competition/{competitionId}` | Bundle. |
| GET | `/fantasy/user/{userId}/competition/{competitionId}/leagues` | Bundle. |
| GET | `/fantasy/user/{userId}/competition/{competitionId}/rounds` | Bundle. |
| GET | `/fantasy/user/{userId}/competition/{competitionId}/transfers` | Bundle. |
| GET | `/fantasy/user/{userId}/round/{roundId}/squad` | Bundle. |
| GET | `/fantasy/user/{userId}/round/{roundId}/ranking-overview` | Bundle. |
| GET | `/fantasy/user/{userId}/league/{leagueId}/leaderboards` | Bundle. |
| GET | `/fantasy/branding/{id}/logo` | Bundle/Image. |

## User / Account / Social

Likely auth/state sensitive.

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/user-account/{userId}` | Wrapper/Bundle. |
| GET | `/flare/user/{userId}` | Wrapper. |
| GET | `/user-account/{userId}/predictions/last/0` | Wrapper. |
| GET | `/user-account/{userId}/predictions/next/0` | Wrapper. |
| GET | `/user-account/{userId}/predictions-future` | Bundle. |
| GET | `/user-account/{userId}/predictions/{filter}` | Bundle. |
| GET | `/user-account/{userId}/subscriptions` | Bundle. |
| GET | `/user-account/{userId}/unique-tournaments` | Bundle. |
| GET | `/user-account/{userId}/contributions` | Bundle. |
| GET | `/user-account/{userId}/contributions-count` | Bundle. |
| GET | `/user-account/{userId}/credibility-score-graph` | Bundle. |
| GET | `/user-account/{userId}/editor-events-count` | Bundle. |
| GET | `/user-account/{userId}/event-openings-graph` | Bundle. |
| GET | `/user-account/{userId}/popular-events-action` | Bundle. |
| GET | `/user-account/{userId}/chat-image` | Bundle/Image. |
| GET | `/user-account/contribution-ranking-score` | Wrapper/Bundle. |
| GET | `/user-account/vote-ranking` | Wrapper/Bundle. |
| GET | `/user-account/editor-ranking` | Wrapper/Bundle. |

## News

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/media/news-articles/sport/football` | Wrapper. |
| GET | `/event/{eventId}/media/news` | Bundle. |
| GET | `/event/{eventId}/media/summary/country/{countryCode}` | Bundle. |
| GET | `/player/{playerId}/media` | Bundle. |
| GET | `/team/{teamId}/media` | Verified. |
| GET | `/unique-tournament/{id}/media` | Wrapper/Bundle. |
| GET | `/sofascore-news/{lang}/posts?page={page}&per_page={count}&categories={category}` | Community. |
| GET | `https://www.sofascore.com/news/category/app/iphone/feed/` | Wrapper, raw non-API feed. |

## Images

| Method | Endpoint | Notes |
|---|---|---|
| GET | `https://img.sofascore.com/api/v1/team/{teamId}/image` | Team/player/fighter image depending entity type. |
| GET | `https://img.sofascore.com/api/v1/player/{playerId}/image` | Player image. |
| GET | `https://img.sofascore.com/api/v1/unique-tournament/{id}/image` | Tournament image. |
| GET | `https://img.sofascore.com/api/v1/unique-tournament/{id}/image/dark` | Dark tournament image. |
| GET | `https://img.sofascore.com/api/v1/stage/{stageId}/image` | Motorsport stage image. |
| GET | `https://img.sofascore.com/api/v1/unique-stage/{id}/image` | Unique stage image. |
| GET | `https://www.sofascore.com/static/images/flags/{flag}.png` | Flag image. |

## Status Codes / Common Fields

Common football status codes observed in community docs and responses:

| Code | Meaning | Type |
|---:|---|---|
| 0 | Not started | `notstarted` |
| 6 | 1st half | `inprogress` |
| 7 | 2nd half | `inprogress` |
| 31 | Halftime | `inprogress` |
| 60 | Postponed | `postponed` |
| 70 | Cancelled | `cancelled` |
| 100 | Ended | `finished` |
| 110 | After extra time | `finished` |
| 120 | After penalties | `finished` |

Common event fields:

```text
id
customId
slug
startTimestamp
status
tournament
season
roundInfo
homeTeam
awayTeam
homeScore
awayScore
winnerCode
time
changes
hasXg
hasEventPlayerStatistics
hasEventPlayerHeatMap
venue
referee
```

## Routes Found In Current Web Bundle But Not Fully Normalized

The current web bundle contains dynamic template strings such as:

```text
/calendar/${e}/${t}/${r}/stages
/calendar/${e}/${t}/${r}/unique-tournaments
/category/${e}/${t}/${r}/unique-tournament-event-count
/config/default-unique-tournaments/${e}${t?...}
/event/${e}/comments${...}
/event/${e}/live-action-widget${...}
/fantasy/competition/${e}${...}
/fantasy/league/${e}${...}
/odds/${e}/dropping/${t||...}
/odds/top-team-streaks/${e}/${t||...}
/rankings/${e}${...}
/sport/${e}/categories${...}
/sport/${e}/scheduled-events/${t}${...}
/team/${e}/events${...}
/unique-tournament/${e}${...}
/unique-tournament/${e}/season/${t}/statistics?${...}
```

I normalized routes where the parameter meaning was clear. For bundle strings with query builders or minified optional fragments, keep the exact website network tab as the final authority before implementing.
