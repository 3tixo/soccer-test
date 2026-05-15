# Verification Log

Verification date: 2026-05-15

## Method

I tested routes against:

```text
https://api.sofascore.com/api/v1
```

Plain PowerShell `Invoke-WebRequest` returned `403 Forbidden` for normal routes. A Python `curl_cffi` session with `impersonate="chrome"` returned successful responses.

Headers used in the successful session:

```text
Referer: https://www.sofascore.com/
Origin: https://www.sofascore.com
Accept: application/json, text/plain, */*
Accept-Language: en-US,en;q=0.9
```

## Plain HTTP Results

All of these returned `403 Forbidden` with plain PowerShell HTTP:

```text
/sport/football/categories
/sport/football/categories/all
/sport/football/scheduled-events/2026-05-15
/sport/football/events/live
/sport/football/live-tournaments
/search/all?q=Barcelona
/team/2817
/team/2817/players
/team/2817/events/last/0
/player/934235
/player/934235/transfer-history
/unique-tournament/17/seasons
/unique-tournament/17
/category/1/unique-tournaments
```

## Successful Chrome-TLS Results

| Status | Endpoint | Top-level keys |
|---:|---|---|
| 200 | `/sport/football/categories` | `categories` |
| 200 | `/sport/football/categories/all` | `categories` |
| 200 | `/sport/football/scheduled-events/2026-05-15` | `events` |
| 200 | `/sport/football/events/live` | `events` |
| 200 | `/sport/football/live-tournaments` | `liveTournaments` |
| 200 | `/search/all?q=Barcelona` | `results` |
| 200 | `/team/2817` | `team`, `pregameForm` |
| 200 | `/team/2817/players` | `players`, `foreignPlayers`, `nationalPlayers`, `supportStaff`, `playerPreviousTeam`, `nationalTeamPlayerStatistics`, `teamDepthAssignments` |
| 200 | `/team/2817/events/last/0` | `events`, `hasNextPage` |
| 200 | `/player/934235` | `player` |
| 200 | `/player/934235/transfer-history` | `transferHistory` |
| 200 | `/unique-tournament/17/seasons` | `seasons` |
| 200 | `/unique-tournament/17` | `uniqueTournament` |
| 200 | `/category/1/unique-tournaments` | `groups` |

## Event Endpoint Verification

Discovered test event from Barcelona recent events:

```text
eventId: 14083203
customId: ogbsrgb
homeTeamId: 2814
awayTeamId: 2817
```

| Status | Endpoint | Top-level keys / note |
|---:|---|---|
| 200 | `/event/14083203` | `event` |
| 200 | `/event/14083203/incidents` | `incidents`, `home`, `away` |
| 200 | `/event/14083203/statistics` | `statistics` |
| 200 | `/event/14083203/lineups` | `confirmed`, `home`, `away`, `statisticalVersion` |
| 200 | `/event/14083203/shotmap` | `shotmap` |
| 404 | `/event/14083203/shotmap/2814` | team shotmap variant not available for this event |
| 200 | `/event/14083203/heatmap/2814` | `playerPoints`, `goalkeeperPoints` |
| 200 | `/event/14083203/graph` | `graphPoints`, `periodTime`, `overtimeLength`, `periodCount` |
| 404 | `/event/14083203/graph/win-probability` | valid-looking route, no data for this event |
| 200 | `/event/14083203/h2h` | `teamDuel`, `managerDuel` |
| 200 | `/event/ogbsrgb/h2h/events` | `events` |
| 200 | `/event/14083203/best-players/summary` | `bestHomeTeamPlayers`, `bestAwayTeamPlayers`, `playerOfTheMatch` |
| 200 | `/event/14083203/average-positions` | `home`, `away`, `substitutions` |
| 200 | `/event/14083203/pregame-form` | `homeTeam`, `awayTeam`, `label` |
| 200 | `/event/14083203/team-streaks` | `general`, `head2head` |
| 200 | `/event/14083203/managers` | `homeManager`, `awayManager` |
| 200 | `/event/14083203/votes` | `vote`, `bothTeamsToScoreVote`, `firstTeamToScoreVote`, `whoShouldHaveWonVote` |
| 200 | `/event/14083203/comments` | `comments`, `home`, `away` |
| 200 | `/event/14083203/highlights` | `highlights` |
| 200 | `/event/14083203/odds/1/featured` | `featured`, `hasMoreOdds` |
| 200 | `/event/14083203/odds/1/all` | `markets`, `eventId` |
| 200 | `/event/14083203/provider/1/winning-odds` | `home`, `away` |
| 404 | `/tv/event/14083203/country-channels` | no TV data for this event |
| 200 | `/fantasy/event/14083203` | `competitionId`, `eventStatusType`, `playerScores`, `playerStatistics`, `config` |

## Tournament / Team / Player Verification

Current Premier League season discovered from `/unique-tournament/17/seasons`:

```text
seasonId: 76986
```

| Status | Endpoint | Top-level keys / note |
|---:|---|---|
| 200 | `/unique-tournament/17/season/76986/info` | `info` |
| 200 | `/unique-tournament/17/season/76986/standings/total` | `standings` |
| 200 | `/unique-tournament/17/season/76986/standings/home` | `standings` |
| 200 | `/unique-tournament/17/season/76986/standings/away` | `standings` |
| 200 | `/unique-tournament/17/season/76986/rounds` | `currentRound`, `rounds` |
| 200 | `/unique-tournament/17/season/76986/events/last/0` | `events`, `hasNextPage` |
| 200 | `/unique-tournament/17/season/76986/events/next/0` | `events`, `hasNextPage` |
| 200 | `/unique-tournament/17/season/76986/top-players/overall` | `topPlayers`, `statisticsType` |
| 404 | `/unique-tournament/17/season/76986/top-players/goals` | route shape from community docs, not valid for this season/test |
| 200 | `/unique-tournament/17/season/76986/top-teams/overall` | `topTeams`, `statisticsType` |
| 200 | `/unique-tournament/17/season/76986/top-players-per-game/all/overall` | `topPlayers`, `statisticsType` |
| 200 | `/unique-tournament/17/season/76986/team-of-the-week/rounds` | `rounds` |
| 200 | `/team/2817/team-statistics/seasons` | `uniqueTournamentSeasons`, `typesMap` |
| 200 | `/team/2817/unique-tournament/8/season/77559/statistics/overall` | `statistics` |
| 200 | `/team/2817/unique-tournament/8/season/77559/top-players/overall` | `topPlayers`, `statisticsType` |
| 200 | `/team/2817/transfers` | `transfersIn`, `transfersOut` |
| 200 | `/team/2817/near-events` | `previousEvent`, `nextEvent` |
| 200 | `/team/2817/media` | `media` |
| 200 | `/player/934235/statistics/seasons` | `uniqueTournamentSeasons`, `typesMap` |
| 200 | `/player/934235/unique-tournaments` | `uniqueTournaments` |
| 200 | `/player/934235/attribute-overviews` | `averageAttributeOverviews`, `playerAttributeOverviews` |
| 200 | `/player/934235/national-team-statistics` | `statistics` |

## Search / Other Sports Verification

| Status | Endpoint | Top-level keys |
|---:|---|---|
| 200 | `/search/events/?q=Barcelona&page=0` | `results` |
| 200 | `/search/player-team-persons/?q=saka&page=0` | `results` |
| 200 | `/search/teams/?q=arsenal&page=0` | `results` |
| 200 | `/search/unique-tournaments/?q=premier%20league&page=0` | `results` |
| 200 | `/sport/basketball/events/live` | `events` |
| 200 | `/sport/tennis/categories` | `categories` |
| 200 | `/sport/mma/events/live` | `events` |
| 200 | `/sport/motorsport/categories` | `categories` |
| 200 | `/odds/providers/US/web` | `providers` |

