const SITE_API = "https://site.api.espn.com/apis";
const CORE_API = "https://sports.core.api.espn.com/v2/sports";
const ALERTS_ENABLED_KEY = "pitchpulse.alerts.enabled";
const ALERTS_SEEN_KEY = "pitchpulse.alerts.seen";

const LEAGUES = [
  { id: "eng.1", name: "Premier League", country: "England", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/23.png" },
  { id: "esp.1", name: "LALIGA", country: "Spain", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/15.png" },
  { id: "ita.1", name: "Serie A", country: "Italy", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/12.png" },
  { id: "ger.1", name: "Bundesliga", country: "Germany", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/10.png" },
  { id: "fra.1", name: "Ligue 1", country: "France", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/9.png" },
  { id: "uefa.champions", name: "Champions League", country: "Europe", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/2.png" },
  { id: "uefa.europa", name: "Europa League", country: "Europe", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png" },
  { id: "usa.1", name: "MLS", country: "United States", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/19.png" },
  { id: "eng.2", name: "Championship", country: "England", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/24.png" },
  { id: "por.1", name: "Liga Portugal", country: "Portugal", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/14.png" },
  { id: "ned.1", name: "Eredivisie", country: "Netherlands", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/11.png" },
  { id: "mex.1", name: "Liga MX", country: "Mexico", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/22.png" },
  { id: "fifa.world", name: "World Cup", country: "International", logo: "https://a.espncdn.com/i/leaguelogos/soccer/500/4.png" },
];

const state = {
  leagueId: "eng.1",
  activeTab: "matches",
  date: new Date(),
  hasUserPickedDate: false,
  scoreboard: null,
  standings: null,
  news: null,
  selectedTeamId: null,
  hasCompletedInitialLoad: false,
  alertsEnabled: localStorage.getItem(ALERTS_ENABLED_KEY) === "true",
  alertSeenKeys: loadAlertSeenKeys(),
  summaryCache: new Map(),
  competitionCache: new Map(),
  teamCache: new Map(),
};

const els = {
  appLoader: document.querySelector("#appLoader"),
  appShell: document.querySelector(".app-shell"),
  leagueStrip: document.querySelector("#leagueStrip"),
  leagueHero: document.querySelector("#leagueHero"),
  alertsButton: document.querySelector("#alertsButton"),
  searchToggle: document.querySelector("#searchToggle"),
  searchPanel: document.querySelector("#searchPanel"),
  leagueSearch: document.querySelector("#leagueSearch"),
  searchResults: document.querySelector("#searchResults"),
  refreshButton: document.querySelector("#refreshButton"),
  prevDate: document.querySelector("#prevDate"),
  nextDate: document.querySelector("#nextDate"),
  todayButton: document.querySelector("#todayButton"),
  datePickerButton: document.querySelector("#datePickerButton"),
  nativeDatePicker: document.querySelector("#nativeDatePicker"),
  dateKicker: document.querySelector("#dateKicker"),
  dateLabel: document.querySelector("#dateLabel"),
  syncLabel: document.querySelector("#syncLabel"),
  matchesTitle: document.querySelector("#matchesTitle"),
  standingsTitle: document.querySelector("#standingsTitle"),
  newsTitle: document.querySelector("#newsTitle"),
  matchesList: document.querySelector("#matchesList"),
  standingsList: document.querySelector("#standingsList"),
  newsList: document.querySelector("#newsList"),
  panels: {
    matches: document.querySelector("#matchesPanel"),
    standings: document.querySelector("#standingsPanel"),
    news: document.querySelector("#newsPanel"),
  },
  matchSheet: document.querySelector("#matchSheet"),
  sheetContent: document.querySelector("#sheetContent"),
  sheetClose: document.querySelector("#sheetClose"),
  sheetBackdrop: document.querySelector("#sheetBackdrop"),
};

document.addEventListener("DOMContentLoaded", init);

function loadAlertSeenKeys() {
  try {
    return new Set(JSON.parse(localStorage.getItem(ALERTS_SEEN_KEY) || "[]"));
  } catch {
    return new Set();
  }
}

function init() {
  bindEvents();
  renderLeagueChips();
  renderDate();
  renderShell();
  renderAlertsButton();
  hydrateIcons();
  registerServiceWorker();
  startScorePolling();
  loadLeagueData({ useEspnDefaultDate: true });
}

function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) return;

  window.addEventListener("load", () => {
    navigator.serviceWorker.register("service-worker.js").catch((error) => {
      console.warn("Service worker registration failed", error);
    });
  });
}

function getLocalNotifications() {
  return window.Capacitor?.Plugins?.LocalNotifications || null;
}

async function toggleMatchAlerts() {
  if (state.alertsEnabled) {
    state.alertsEnabled = false;
    localStorage.setItem(ALERTS_ENABLED_KEY, "false");
    cancelUpcomingKickoffAlerts(state.scoreboard?.events ?? []).catch((error) => {
      console.warn("Could not cancel kickoff alerts", error);
    });
    renderAlertsButton();
    return;
  }

  const granted = await requestNotificationAccess();
  if (!granted) {
    alert("Notifications are blocked. Enable them in iPhone Settings for the IPA, then turn alerts on again.");
    renderAlertsButton();
    return;
  }

  state.alertsEnabled = true;
  localStorage.setItem(ALERTS_ENABLED_KEY, "true");
  seedAlertKeys(state.scoreboard?.events ?? []);
  renderAlertsButton();
  await sendAppNotification("PitchPulse alerts on", "Score, kickoff, and full-time alerts are enabled for the current league.")
    .catch((error) => console.warn("Could not show notification", error));
  await scheduleUpcomingKickoffAlerts(state.scoreboard?.events ?? [])
    .catch((error) => console.warn("Could not schedule kickoff alerts", error));
}

async function requestNotificationAccess() {
  const localNotifications = getLocalNotifications();

  if (localNotifications) {
    const current = await localNotifications.checkPermissions();
    if (current.display === "granted") return true;
    const requested = await localNotifications.requestPermissions();
    return requested.display === "granted";
  }

  if (!("Notification" in window)) return false;
  if (Notification.permission === "granted") return true;
  if (Notification.permission === "denied") return false;
  return (await Notification.requestPermission()) === "granted";
}

function renderAlertsButton() {
  if (!els.alertsButton) return;
  els.alertsButton.classList.toggle("active", state.alertsEnabled);
  els.alertsButton.setAttribute("aria-label", state.alertsEnabled ? "Disable match alerts" : "Enable match alerts");
  els.alertsButton.title = state.alertsEnabled ? "Match alerts on" : "Match alerts off";
}

function handleMatchAlerts(previousEvents = [], nextEvents = []) {
  if (!state.alertsEnabled) return;

  if (!previousEvents.length) {
    seedAlertKeys(nextEvents);
    return;
  }

  const previousById = new Map(previousEvents.map((event) => [String(event.id), event]));
  nextEvents.forEach((event) => {
    const alertKey = getAlertKey(event);
    const previous = previousById.get(String(event.id));
    if (!previous || state.alertSeenKeys.has(alertKey)) {
      state.alertSeenKeys.add(alertKey);
      return;
    }

    if (hasAlertWorthyChange(previous, event)) {
      const message = buildMatchAlert(event, previous);
      sendAppNotification(message.title, message.body).catch((error) => {
        console.warn("Could not show notification", error);
      });
    }
    state.alertSeenKeys.add(alertKey);
  });
  persistAlertKeys();
}

function seedAlertKeys(events = []) {
  events.forEach((event) => state.alertSeenKeys.add(getAlertKey(event)));
  persistAlertKeys();
}

function persistAlertKeys() {
  const keys = [...state.alertSeenKeys].slice(-120);
  state.alertSeenKeys = new Set(keys);
  localStorage.setItem(ALERTS_SEEN_KEY, JSON.stringify(keys));
}

function getAlertKey(event) {
  const teams = normalizeCompetitors(event.competitions?.[0]?.competitors);
  const status = event.status?.type ?? {};
  return [
    event.id,
    status.state || "",
    status.completed ? "done" : "open",
    teams.home.score ?? "-",
    teams.away.score ?? "-",
  ].join(":");
}

function hasAlertWorthyChange(previous, current) {
  const oldTeams = normalizeCompetitors(previous.competitions?.[0]?.competitors);
  const newTeams = normalizeCompetitors(current.competitions?.[0]?.competitors);
  const oldStatus = previous.status?.type ?? {};
  const newStatus = current.status?.type ?? {};

  return oldTeams.home.score !== newTeams.home.score
    || oldTeams.away.score !== newTeams.away.score
    || oldStatus.state !== newStatus.state
    || Boolean(oldStatus.completed) !== Boolean(newStatus.completed);
}

function buildMatchAlert(event, previous) {
  const teams = normalizeCompetitors(event.competitions?.[0]?.competitors);
  const oldTeams = normalizeCompetitors(previous.competitions?.[0]?.competitors);
  const status = event.status?.type ?? {};
  const oldStatus = previous.status?.type ?? {};
  const score = `${teams.home.score ?? "-"}-${teams.away.score ?? "-"}`;
  const fixture = `${teams.home.displayName} vs ${teams.away.displayName}`;

  if (oldTeams.home.score !== teams.home.score || oldTeams.away.score !== teams.away.score) {
    return {
      title: `Goal update: ${score}`,
      body: fixture,
    };
  }

  if (oldStatus.state === "pre" && status.state === "in") {
    return {
      title: "Kickoff",
      body: fixture,
    };
  }

  if (!oldStatus.completed && status.completed) {
    return {
      title: `Full time: ${score}`,
      body: fixture,
    };
  }

  return {
    title: "Match update",
    body: `${fixture} ${score}`,
  };
}

async function sendAppNotification(title, body) {
  const localNotifications = getLocalNotifications();

  if (localNotifications) {
    await localNotifications.schedule({
      notifications: [{
        id: makeNotificationId(`${Date.now()}:${title}:${body}`),
        title,
        body,
        schedule: { at: new Date(Date.now() + 300) },
        sound: "default",
      }],
    });
    return;
  }

  if (!("Notification" in window) || Notification.permission !== "granted") return;
  if ("serviceWorker" in navigator) {
    const registration = await navigator.serviceWorker.ready;
    registration.showNotification(title, {
      body,
      icon: "icons/icon-192.svg",
      badge: "icons/icon-192.svg",
    });
    return;
  }

  new Notification(title, { body, icon: "icons/icon-192.svg" });
}

async function scheduleUpcomingKickoffAlerts(events = []) {
  if (!state.alertsEnabled) return;
  const localNotifications = getLocalNotifications();
  if (!localNotifications) return;

  const now = Date.now();
  const notifications = events
    .filter((event) => event.status?.type?.state === "pre" && event.date)
    .map((event) => ({ event, at: new Date(event.date) }))
    .filter(({ at }) => at.getTime() > now + 60000)
    .slice(0, 20)
    .map(({ event, at }) => {
      const teams = normalizeCompetitors(event.competitions?.[0]?.competitors);
      return {
        id: makeNotificationId(`kickoff:${event.id}`),
        title: `Kickoff: ${teams.home.displayName} vs ${teams.away.displayName}`,
        body: `${getLeagueName()} starts at ${formatTime(at)}`,
        schedule: { at },
        sound: "default",
      };
    });

  if (notifications.length) {
    await localNotifications.schedule({ notifications });
  }
}

async function cancelUpcomingKickoffAlerts(events = []) {
  const localNotifications = getLocalNotifications();
  if (!localNotifications || !events.length) return;

  await localNotifications.cancel({
    notifications: events.map((event) => ({ id: makeNotificationId(`kickoff:${event.id}`) })),
  });
}

function makeNotificationId(value) {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash << 5) - hash) + value.charCodeAt(index);
    hash |= 0;
  }
  return Math.abs(hash % 2147483647) || 1;
}

function bindEvents() {
  els.alertsButton.addEventListener("click", toggleMatchAlerts);

  els.searchToggle.addEventListener("click", () => {
    els.searchPanel.hidden = !els.searchPanel.hidden;
    if (!els.searchPanel.hidden) els.leagueSearch.focus();
  });

  els.leagueSearch.addEventListener("input", () => {
    renderLeagueChips(els.leagueSearch.value);
    renderSearchResults(els.leagueSearch.value);
  });

  els.refreshButton.addEventListener("click", () => loadLeagueData({ force: true }));

  els.prevDate.addEventListener("click", () => shiftDate(-1));
  els.nextDate.addEventListener("click", () => shiftDate(1));
  els.todayButton.addEventListener("click", () => {
    state.date = new Date();
    state.hasUserPickedDate = true;
    loadLeagueData();
  });

  els.datePickerButton.addEventListener("click", () => {
    if (typeof els.nativeDatePicker.showPicker === "function") {
      els.nativeDatePicker.showPicker();
    } else {
      els.nativeDatePicker.focus();
    }
  });

  els.nativeDatePicker.addEventListener("change", () => {
    if (!els.nativeDatePicker.value) return;
    state.date = fromDateInputValue(els.nativeDatePicker.value);
    state.hasUserPickedDate = true;
    loadLeagueData();
  });

  document.querySelectorAll(".tab-button").forEach((button) => {
    button.addEventListener("click", () => setTab(button.dataset.tab));
  });

  els.sheetClose.addEventListener("click", closeSheet);
  els.sheetBackdrop.addEventListener("click", closeSheet);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeSheet();
  });
}

function startScorePolling() {
  window.setInterval(() => {
    if (document.visibilityState !== "visible") return;
    if (!isSameLocalDay(state.date, new Date())) return;
    loadLeagueData({ force: true, silent: true });
  }, 60000);
}

function renderLeagueChips(filter = "") {
  const query = filter.trim().toLowerCase();
  const leagues = LEAGUES.filter((league) => {
    return `${league.name} ${league.country} ${league.id}`.toLowerCase().includes(query);
  });

  els.leagueStrip.innerHTML = leagues.map((league) => `
    <button class="chip ${league.id === state.leagueId ? "active" : ""}" data-league="${league.id}" type="button">
      <img src="${league.logo}" alt="" loading="lazy" onerror="this.style.visibility='hidden'" />
      <span>${escapeHtml(league.name)}</span>
    </button>
  `).join("");

  els.leagueStrip.querySelectorAll(".chip").forEach((button) => {
    button.addEventListener("click", () => {
      state.leagueId = button.dataset.league;
      state.hasUserPickedDate = false;
      state.scoreboard = null;
      state.standings = null;
      state.news = null;
      state.selectedTeamId = null;
      els.searchPanel.hidden = true;
      els.leagueSearch.value = "";
      els.searchResults.innerHTML = "";
      renderLeagueChips(els.leagueSearch.value);
      loadLeagueData({ useEspnDefaultDate: true });
    });
  });
}

function renderSearchResults(filter = "") {
  const query = filter.trim().toLowerCase();
  if (!query) {
    els.searchResults.innerHTML = "";
    return;
  }

  const leagues = LEAGUES
    .filter((league) => `${league.name} ${league.country} ${league.id}`.toLowerCase().includes(query))
    .slice(0, 4)
    .map((league) => ({ type: "league", id: league.id, title: league.name, subtitle: league.country, logo: league.logo }));

  const teams = getSearchableTeams()
    .filter((team) => `${team.displayName} ${team.abbreviation} ${team.leagueName}`.toLowerCase().includes(query))
    .slice(0, 8)
    .map((team) => ({ type: "team", ...team }));

  const results = [...teams, ...leagues].slice(0, 10);

  if (!results.length) {
    els.searchResults.innerHTML = emptyState("No results", "Try a team or competition name.");
    return;
  }

  els.searchResults.innerHTML = results.map(renderSearchResult).join("");
  els.searchResults.querySelectorAll(".search-result").forEach((button) => {
    button.addEventListener("click", () => {
      if (button.dataset.type === "league") {
        selectLeagueFromSearch(button.dataset.id);
      } else {
        selectTeamFromSearch(button.dataset.id);
      }
    });
  });
  hydrateIcons();
}

function renderSearchResult(result) {
  const isTeam = result.type === "team";
  return `
    <button class="search-result" type="button" data-type="${result.type}" data-id="${result.id}">
      ${result.logo ? `<img src="${result.logo}" alt="" loading="lazy" onerror="this.style.visibility='hidden'" />` : `<span class="search-result-icon"><i data-lucide="${isTeam ? "shield" : "trophy"}"></i></span>`}
      <span class="search-result-copy">
        <strong>${escapeHtml(result.title || result.displayName)}</strong>
        <span>${escapeHtml(result.subtitle || result.abbreviation || result.leagueName || "")}</span>
      </span>
      <span class="search-result-type">${isTeam ? "Team" : "League"}</span>
    </button>
  `;
}

function selectLeagueFromSearch(leagueId) {
  state.leagueId = leagueId;
  state.hasUserPickedDate = false;
  state.scoreboard = null;
  state.standings = null;
  state.news = null;
  state.selectedTeamId = null;
  els.searchPanel.hidden = true;
  els.leagueSearch.value = "";
  els.searchResults.innerHTML = "";
  renderLeagueChips();
  loadLeagueData({ useEspnDefaultDate: true });
}

function selectTeamFromSearch(teamId) {
  state.selectedTeamId = teamId;
  els.searchPanel.hidden = true;
  els.leagueSearch.value = "";
  els.searchResults.innerHTML = "";
  openTeam(teamId);
  setTab("matches");
  renderShell();
  renderMatches();
  renderStandings();
  requestAnimationFrame(() => {
    const row = document.querySelector(`[data-team-id="${escapeSelectorValue(teamId)}"]`);
    row?.scrollIntoView({ block: "center", behavior: "smooth" });
  });
}

function renderShell() {
  const league = getLeague();
  const eventCount = state.scoreboard?.events?.length ?? 0;
  const liveCount = (state.scoreboard?.events ?? []).filter((event) => isLive(event.status?.type?.state)).length;
  const tableCount = getStandingsEntries().length;

  els.leagueHero.innerHTML = `
    <img class="league-logo" src="${league.logo}" alt="" onerror="this.style.visibility='hidden'" />
    <div class="league-copy">
      <p class="eyebrow">${escapeHtml(league.country)}</p>
      <h2>${escapeHtml(getLeagueName())}</h2>
      <p>${escapeHtml(getSeasonLabel())}</p>
      <div class="quick-stats" aria-label="Competition snapshot">
        <div class="quick-stat"><span>Matches</span><strong>${eventCount}</strong></div>
        <div class="quick-stat"><span>Live</span><strong>${liveCount}</strong></div>
        <div class="quick-stat"><span>Teams</span><strong>${tableCount || "-"}</strong></div>
      </div>
    </div>
  `;

  const selectedTeam = getSelectedTeam();
  els.matchesTitle.textContent = selectedTeam ? `${selectedTeam.displayName} Matches` : `${getLeagueName()} Matches`;
  els.standingsTitle.textContent = `${getLeagueName()} Table`;
  els.newsTitle.textContent = `${getLeagueName()} News`;
  hydrateIcons();
}

function setTab(tab) {
  state.activeTab = tab;
  document.querySelectorAll(".tab-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === tab);
  });
  Object.entries(els.panels).forEach(([name, panel]) => {
    panel.classList.toggle("active", name === tab);
  });
}

function shiftDate(days) {
  const next = new Date(state.date);
  next.setDate(next.getDate() + days);
  state.date = next;
  state.hasUserPickedDate = true;
  loadLeagueData();
}

async function loadLeagueData(options = {}) {
  if (!options.silent) setLoading(true);
  renderDate();
  if (!options.silent) renderLoadingCards();
  const previousEvents = state.scoreboard?.events ?? [];

  try {
    const [scoreboardResult, standingsResult, newsResult] = await Promise.allSettled([
      fetchScoreboard(options),
      fetchJson(`${SITE_API}/v2/sports/soccer/${state.leagueId}/standings`, options.force),
      fetchJson(`${SITE_API}/site/v2/sports/soccer/${state.leagueId}/news`, options.force),
    ]);

    if ([scoreboardResult, standingsResult, newsResult].every((result) => result.status === "rejected")) {
      throw scoreboardResult.reason || standingsResult.reason || newsResult.reason;
    }

    const scoreboard = unwrapResult(scoreboardResult);
    const standings = unwrapResult(standingsResult);
    const news = unwrapResult(newsResult);

    state.scoreboard = scoreboard;
    state.standings = standings;
    state.news = news;
    handleMatchAlerts(previousEvents, scoreboard?.events ?? []);
    scheduleUpcomingKickoffAlerts(scoreboard?.events ?? []).catch((error) => {
      console.warn("Could not schedule kickoff alerts", error);
    });

    if (options.useEspnDefaultDate && scoreboard?.day?.date) {
      state.date = fromApiDay(scoreboard.day.date);
      renderDate();
    }

    renderShell();
    scoreboardResult.status === "fulfilled"
      ? renderMatches()
      : renderPanelError(els.matchesList, "Could not load scores", scoreboardResult.reason);
    standingsResult.status === "fulfilled"
      ? renderStandings()
      : renderPanelError(els.standingsList, "Could not load standings", standingsResult.reason);
    newsResult.status === "fulfilled"
      ? renderNews()
      : renderPanelError(els.newsList, "Could not load news", newsResult.reason);
    if (!els.searchPanel.hidden && els.leagueSearch.value) {
      renderSearchResults(els.leagueSearch.value);
    }
    setSyncLabel();
  } catch (error) {
    if (options.silent) {
      console.warn("Silent ESPN refresh failed", error);
    } else {
      renderError(error);
    }
  } finally {
    if (!options.silent) {
      setLoading(false);
      finishInitialLoad();
    }
    hydrateIcons();
  }
}

function unwrapResult(result) {
  return result.status === "fulfilled" ? result.value : null;
}

async function fetchScoreboard(options = {}) {
  const dateQuery = state.hasUserPickedDate || !options.useEspnDefaultDate
    ? `?dates=${formatApiDate(state.date)}`
    : "";
  return fetchJson(`${SITE_API}/site/v2/sports/soccer/${state.leagueId}/scoreboard${dateQuery}`, options.force);
}

const responseCache = new Map();

async function fetchJson(url, force = false) {
  const cached = responseCache.get(url);
  if (!force && cached && Date.now() - cached.time < 30000) {
    return cached.data;
  }

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`ESPN returned ${response.status} for ${new URL(url).pathname}`);
  }

  const data = await response.json();
  responseCache.set(url, { time: Date.now(), data });
  return data;
}

function renderDate() {
  els.dateLabel.textContent = formatDateLabel(state.date);
  els.dateKicker.textContent = isSameLocalDay(state.date, new Date()) ? "Today" : "Match day";
  els.nativeDatePicker.value = toDateInputValue(state.date);
}

function renderLoadingCards() {
  els.matchesList.innerHTML = Array.from({ length: 3 }, () => `<div class="match-card skeleton"></div>`).join("");
  els.standingsList.innerHTML = `<div class="state-card skeleton"></div>`;
  els.newsList.innerHTML = Array.from({ length: 3 }, () => `<div class="news-card skeleton"></div>`).join("");
}

function renderMatches() {
  const allEvents = state.scoreboard?.events ?? [];
  const events = state.selectedTeamId
    ? allEvents.filter((event) => eventHasTeam(event, state.selectedTeamId))
    : allEvents;

  if (!events.length) {
    els.matchesList.innerHTML = emptyState(
      state.selectedTeamId ? "No matches for this team" : "No matches on this date",
      state.selectedTeamId ? "Try another date or clear the team search by selecting a league." : "Try another day or switch competitions."
    );
    return;
  }

  els.matchesList.innerHTML = events.map(renderMatchCard).join("");
  els.matchesList.querySelectorAll(".match-card").forEach((card) => {
    card.addEventListener("click", (event) => {
      const teamRow = event.target.closest(".team-row[data-team-id]");
      if (teamRow?.dataset.teamId) {
        openTeam(teamRow.dataset.teamId);
        return;
      }
      openMatch(card.dataset.eventId);
    });
  });
}

function renderMatchCard(event) {
  const competition = event.competitions?.[0] ?? {};
  const teams = normalizeCompetitors(competition.competitors);
  const status = event.status?.type ?? {};
  const isPre = status.state === "pre";
  const statusClass = isLive(status.state) ? "live" : status.completed ? "final" : "";
  const leagueName = state.scoreboard?.leagues?.[0]?.abbreviation || getLeagueName();
  const venue = event.venue?.displayName || competition.venue?.fullName || competition.venue?.displayName || "Venue TBA";

  return `
    <button class="match-card" data-event-id="${event.id}" type="button">
      <div class="match-top">
        <span>${escapeHtml(leagueName)}</span>
        <span class="status-pill ${statusClass}">${escapeHtml(status.shortDetail || status.description || "Scheduled")}</span>
      </div>
      <div class="match-body">
        ${renderTeamLine(teams.home, isPre)}
        ${renderTeamLine(teams.away, isPre)}
        <div class="match-meta">
          <i data-lucide="${isPre ? "clock-3" : "map-pin"}"></i>
          <span>${escapeHtml(isPre ? formatTime(event.date) : venue)}</span>
        </div>
      </div>
    </button>
  `;
}

function renderTeamLine(team, isPre) {
  const score = isPre ? team.abbreviation : team.score;
  return `
    <div class="team-row" data-team-id="${escapeHtml(team.id || "")}">
      <img class="team-logo" src="${team.logo}" alt="" loading="lazy" onerror="this.style.visibility='hidden'" />
      <div class="team-name">
        <strong>${escapeHtml(team.displayName)}</strong>
        <span>${escapeHtml(team.record || team.abbreviation || "")}</span>
      </div>
      <div class="score ${isPre ? "pre" : ""}">${escapeHtml(score ?? "-")}</div>
    </div>
  `;
}

function renderStandings() {
  const entries = getStandingsEntries();
  if (!entries.length) {
    els.standingsList.innerHTML = emptyState(
      "No table available",
      "ESPN does not expose standings for every competition."
    );
    return;
  }

  els.standingsList.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>#</th>
          <th>Club</th>
          <th>GP</th>
          <th>W</th>
          <th>D</th>
          <th>L</th>
          <th>GD</th>
          <th>Pts</th>
        </tr>
      </thead>
      <tbody>
        ${entries.map(renderStandingRow).join("")}
      </tbody>
    </table>
  `;
  els.standingsList.querySelectorAll(".standing-team[data-team-id]").forEach((team) => {
    team.addEventListener("click", () => openTeam(team.dataset.teamId));
  });
}

function renderStandingRow(entry, index) {
  const team = entry.team ?? {};
  const stats = statMap(entry.stats);
  const rank = pickStat(stats, "rank") || String(index + 1);
  const noteColor = entry.note?.color || "transparent";

  const teamId = String(team.id || "");

  return `
    <tr data-team-id="${escapeHtml(teamId)}" class="${state.selectedTeamId === teamId ? "highlighted-team" : ""}" title="${escapeHtml(entry.note?.description || "")}">
      <td><span class="note-bar" style="background:${escapeHtml(noteColor)}"></span> ${escapeHtml(rank)}</td>
      <td>
        <div class="standing-team" data-team-id="${escapeHtml(teamId)}" role="button" tabindex="0">
          <img class="standing-logo" src="${getTeamLogo(team)}" alt="" loading="lazy" onerror="this.style.visibility='hidden'" />
          <span>${escapeHtml(team.shortDisplayName || team.displayName || team.name || "Team")}</span>
        </div>
      </td>
      <td>${escapeHtml(pickStat(stats, "gamesPlayed"))}</td>
      <td>${escapeHtml(pickStat(stats, "wins"))}</td>
      <td>${escapeHtml(pickStat(stats, "ties"))}</td>
      <td>${escapeHtml(pickStat(stats, "losses"))}</td>
      <td>${escapeHtml(pickStat(stats, "pointDifferential"))}</td>
      <td><strong>${escapeHtml(pickStat(stats, "points"))}</strong></td>
    </tr>
  `;
}

function getSearchableTeams() {
  const teams = new Map();
  const leagueName = getLeagueName();

  getStandingsEntries().forEach((entry) => {
    addSearchableTeam(teams, entry.team, leagueName);
  });

  (state.scoreboard?.events ?? []).forEach((event) => {
    (event.competitions?.[0]?.competitors ?? []).forEach((competitor) => {
      addSearchableTeam(teams, competitor.team, leagueName);
    });
  });

  return [...teams.values()].sort((a, b) => a.displayName.localeCompare(b.displayName));
}

function getSelectedTeam() {
  if (!state.selectedTeamId) return null;
  return getSearchableTeams().find((team) => team.id === state.selectedTeamId) ?? null;
}

function addSearchableTeam(teams, team = {}, leagueName = "") {
  const id = String(team.id || "");
  if (!id || teams.has(id)) return;
  teams.set(id, {
    id,
    displayName: team.displayName || team.shortDisplayName || team.name || "Team",
    title: team.displayName || team.shortDisplayName || team.name || "Team",
    abbreviation: team.abbreviation || "",
    subtitle: `${team.abbreviation || "Team"} - ${leagueName}`,
    leagueName,
    logo: getTeamLogo(team),
  });
}

function eventHasTeam(event, teamId) {
  return (event.competitions?.[0]?.competitors ?? []).some((competitor) => {
    return String(competitor.team?.id || "") === String(teamId);
  });
}

function getStandingForTeam(teamId, standingsData = state.standings, leagueLabel = getLeagueName()) {
  const entries = standingsData === state.standings
    ? getStandingsEntries()
    : getStandingsEntriesFrom(standingsData);
  const entry = entries.find((item) => String(item.team?.id || "") === String(teamId));
  if (!entry) return null;
  const stats = statMap(entry.stats);
  const rank = pickStat(stats, "rank") || "";
  return {
    rank,
    points: pickStat(stats, "points") || "",
    record: stats.get("overall")?.displayValue || stats.get("overall")?.summary || "",
    summary: rank ? `${ordinal(rank)} in ${leagueLabel}` : "",
  };
}

function getStandingsEntriesFrom(standingsData) {
  const children = standingsData?.children ?? [];
  return children.flatMap((child) => child.standings?.entries ?? []);
}

function getTeamResult(event, teamId) {
  const competitors = event.competitions?.[0]?.competitors ?? [];
  const team = competitors.find((competitor) => String(competitor.team?.id || "") === String(teamId));
  const opponent = competitors.find((competitor) => String(competitor.team?.id || "") !== String(teamId));
  if (!team || !opponent) return "-";
  if (team.winner === true) return "W";
  if (team.winner === false && opponent.winner === true) return "L";
  const teamScore = Number(team.score);
  const opponentScore = Number(opponent.score);
  if (Number.isFinite(teamScore) && Number.isFinite(opponentScore)) {
    if (teamScore > opponentScore) return "W";
    if (teamScore < opponentScore) return "L";
    return "D";
  }
  return "-";
}

function isScheduleEventCompleted(event) {
  return Boolean(event.status?.type?.completed || event.competitions?.[0]?.status?.type?.completed);
}

function getOpponentName(event, teamId) {
  const competitors = event.competitions?.[0]?.competitors ?? [];
  const opponent = competitors.find((competitor) => String(competitor.team?.id || "") !== String(teamId));
  const team = competitors.find((competitor) => String(competitor.team?.id || "") === String(teamId));
  if (!opponent?.team) return event.shortName || event.name || "";
  const prefix = team?.homeAway === "home" ? "vs" : "@";
  return `${prefix} ${opponent.team.shortDisplayName || opponent.team.displayName || opponent.team.name}`;
}

function renderNews() {
  const articles = (state.news?.articles ?? []).slice(0, 12);
  if (!articles.length) {
    els.newsList.innerHTML = emptyState(
      "No news available",
      "ESPN did not return articles for this competition."
    );
    return;
  }

  els.newsList.innerHTML = articles.map((article) => {
    const href = article.links?.web?.href || article.links?.mobile?.href || "#";
    const image = article.images?.[0]?.url || "";
    return `
      <a class="news-card" href="${href}" target="_blank" rel="noopener noreferrer">
        ${image ? `<img src="${image}" alt="" loading="lazy" />` : ""}
        <div class="news-copy">
          <h3>${escapeHtml(article.headline || "Untitled")}</h3>
          <p>${escapeHtml(article.description || "")}</p>
          <div class="news-meta">
            <span>${escapeHtml(article.byline || "ESPN")}</span>
            <span>${escapeHtml(formatRelativeDate(article.published || article.lastModified))}</span>
          </div>
        </div>
      </a>
    `;
  }).join("");
}

async function openMatch(eventId) {
  const event = (state.scoreboard?.events ?? []).find((item) => String(item.id) === String(eventId));
  if (!event) return;

  els.matchSheet.hidden = false;
  document.body.style.overflow = "hidden";
  els.sheetContent.innerHTML = renderSheetSkeleton(event);
  hydrateIcons();

  try {
    const cacheKey = `${state.leagueId}:${eventId}`;
    let summary = state.summaryCache.get(cacheKey);
    let competition = state.competitionCache.get(cacheKey);
    if (!summary) {
      const competitionId = event.competitions?.[0]?.id || eventId;
      const [summaryResult, competitionResult] = await Promise.allSettled([
        fetchJson(`${SITE_API}/site/v2/sports/soccer/${state.leagueId}/summary?event=${eventId}`),
        fetchJson(`${CORE_API}/soccer/leagues/${state.leagueId}/events/${eventId}/competitions/${competitionId}`),
      ]);
      if (summaryResult.status === "rejected") throw summaryResult.reason;
      summary = summaryResult.value;
      competition = unwrapResult(competitionResult);
      state.summaryCache.set(cacheKey, summary);
      if (competition) state.competitionCache.set(cacheKey, competition);
    } else if (!competition) {
      const competitionId = event.competitions?.[0]?.id || eventId;
      try {
        competition = await fetchJson(`${CORE_API}/soccer/leagues/${state.leagueId}/events/${eventId}/competitions/${competitionId}`);
        state.competitionCache.set(cacheKey, competition);
      } catch {
        competition = null;
      }
    }
    els.sheetContent.innerHTML = renderMatchSheet(event, summary, competition);
  } catch (error) {
    els.sheetContent.innerHTML = `${renderSheetSkeleton(event)}${emptyState("Details unavailable", error.message)}`;
  } finally {
    hydrateIcons();
  }
}

function closeSheet() {
  els.matchSheet.hidden = true;
  document.body.style.overflow = "";
}

async function openTeam(teamId) {
  if (!teamId) return;

  els.matchSheet.hidden = false;
  document.body.style.overflow = "hidden";
  const fallback = getSearchableTeams().find((team) => team.id === String(teamId));
  els.sheetContent.innerHTML = renderTeamSheetSkeleton({
    ...fallback,
    subtitle: "Loading club details",
    leagueLabel: "Club",
  });
  hydrateIcons();

  try {
    const contextProfile = await fetchJson(`${SITE_API}/site/v2/sports/soccer/${state.leagueId}/teams/${teamId}`);
    const teamLeagueId = getTeamLeagueId(contextProfile, state.leagueId);
    const cacheKey = `${teamLeagueId}:team:${teamId}`;
    let data = state.teamCache.get(cacheKey);
    if (!data) {
      const [profileResult, scheduleResult, standingsResult, newsResult] = await Promise.allSettled([
        teamLeagueId === state.leagueId
          ? Promise.resolve(contextProfile)
          : fetchJson(`${SITE_API}/site/v2/sports/soccer/${teamLeagueId}/teams/${teamId}`),
        fetchJson(`${SITE_API}/site/v2/sports/soccer/${teamLeagueId}/teams/${teamId}/schedule`),
        fetchJson(`${SITE_API}/v2/sports/soccer/${teamLeagueId}/standings`),
        fetchJson(`${SITE_API}/site/v2/sports/soccer/${teamLeagueId}/news?team=${teamId}`),
      ]);
      data = {
        profile: unwrapResult(profileResult),
        schedule: unwrapResult(scheduleResult),
        standings: unwrapResult(standingsResult),
        news: unwrapResult(newsResult),
        leagueId: teamLeagueId,
      };
      state.teamCache.set(cacheKey, data);
    }
    els.sheetContent.innerHTML = renderTeamSheet(teamId, data, fallback);
  } catch (error) {
    els.sheetContent.innerHTML = `${renderTeamSheetSkeleton(fallback)}${emptyState("Team details unavailable", error.message)}`;
  } finally {
    hydrateIcons();
  }
}

function getTeamLeagueId(profile, fallbackLeagueId) {
  return profile?.team?.defaultLeague?.slug
    || profile?.team?.leagueAbbrev
    || fallbackLeagueId;
}

function renderTeamSheetSkeleton(team) {
  return `
    <div class="team-sheet-hero">
      ${team?.logo ? `<img src="${team.logo}" alt="" />` : `<span class="team-sheet-logo"><i data-lucide="shield"></i></span>`}
      <div>
        <p class="eyebrow">${escapeHtml(team?.leagueLabel || getLeagueName())}</p>
        <h2>${escapeHtml(team?.displayName || "Team")}</h2>
        <p>${escapeHtml(team?.subtitle || "Club details")}</p>
      </div>
    </div>
  `;
}

function renderTeamSheet(teamId, data, fallback) {
  const team = mergeTeamData(data.profile?.team, data.schedule?.team, fallback);
  const leagueLabel = getTeamLeagueLabel(data.profile?.team, data.schedule?.team, data.leagueId);
  const standings = getStandingForTeam(teamId, data.standings, leagueLabel);
  const events = data.schedule?.events ?? [];
  const articles = data.news?.articles ?? [];
  const teamSubtitle = standings?.summary
    || data.schedule?.team?.standingSummary
    || data.schedule?.team?.recordSummary
    || fallback?.subtitle
    || leagueLabel;

  return `
    ${renderTeamSheetSkeleton({
      displayName: team.displayName || fallback?.displayName,
      subtitle: teamSubtitle,
      logo: getTeamLogo(team) || team.logo || fallback?.logo,
      leagueLabel,
    })}
    <div class="detail-grid">
      ${renderTeamSnapshot(team, standings, leagueLabel)}
      ${renderTeamForm(events, teamId)}
      ${renderTeamSchedule(events, teamId)}
      ${renderTeamNews(articles)}
    </div>
  `;
}

function mergeTeamData(...sources) {
  return sources.reduce((merged, source) => ({ ...merged, ...(source || {}) }), {});
}

function getTeamLeagueLabel(profileTeam, scheduleTeam, leagueId) {
  return profileTeam?.defaultLeague?.name
    || scheduleTeam?.league?.name
    || LEAGUES.find((league) => league.id === leagueId)?.name
    || getLeagueName();
}

function renderTeamSnapshot(team, standings, leagueLabel) {
  const record = standings?.record || team.recordSummary || team.record?.items?.[0]?.summary || "-";
  const position = standings?.summary || "No table position";
  return `
    <div class="detail-block">
      <h3>Club</h3>
      <div class="team-snapshot">
        <div><span>Standing</span><strong>${escapeHtml(position)}</strong></div>
        <div><span>Record</span><strong>${escapeHtml(record)}</strong></div>
      </div>
    </div>
  `;
}

function renderTeamForm(events, teamId) {
  const completed = events
    .filter((event) => event.status?.type?.completed || event.competitions?.[0]?.status?.type?.completed)
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .slice(0, 6);

  if (!completed.length) return "";

  return `
    <div class="detail-block">
      <h3>Recent form</h3>
      <div class="event-strip">
        ${completed.map((event) => {
          const result = getTeamResult(event, teamId);
          const cls = result === "W" ? "win" : result === "L" ? "loss" : "draw";
          return `<span class="form-pill ${cls}" title="${escapeHtml(event.shortName || event.name || "")}">${escapeHtml(result)}</span>`;
        }).join("")}
      </div>
    </div>
  `;
}

function renderTeamSchedule(events, teamId) {
  const now = Date.now();
  const upcoming = events
    .filter((event) => new Date(event.date).getTime() >= now && !isScheduleEventCompleted(event))
    .sort((a, b) => new Date(a.date) - new Date(b.date))
    .slice(0, 5);
  const latest = events
    .filter((event) => new Date(event.date).getTime() < now || isScheduleEventCompleted(event))
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .slice(0, 5);
  const shown = upcoming.length ? upcoming : latest;
  const title = upcoming.length ? "Schedule" : "Latest results";

  if (!shown.length) return "";

  return `
    <div class="detail-block">
      <h3>${title}</h3>
      <div class="team-schedule">
        ${shown.map((event) => {
          const opponent = getOpponentName(event, teamId);
          const result = isScheduleEventCompleted(event) ? getTeamResult(event, teamId) : "";
          return `
            <div class="schedule-row">
              <span>${escapeHtml(formatDateLabel(new Date(event.date)))}</span>
              <strong>${escapeHtml(opponent || event.shortName || event.name || "Match")}</strong>
              <em>${escapeHtml(result || formatTime(event.date))}</em>
            </div>
          `;
        }).join("")}
      </div>
    </div>
  `;
}

function renderTeamNews(articles) {
  const items = articles.slice(0, 4);
  if (!items.length) {
    return `
      <div class="detail-block">
        <h3>Team news</h3>
        ${emptyState("No team news", "ESPN did not return articles for this club.")}
      </div>
    `;
  }

  return `
    <div class="detail-block">
      <h3>Team news</h3>
      <div class="news-list">
        ${items.map((article) => `
          <a class="news-card" href="${article.links?.web?.href || "#"}" target="_blank" rel="noopener noreferrer">
            ${article.images?.[0]?.url ? `<img src="${article.images[0].url}" alt="" loading="lazy" />` : ""}
            <div class="news-copy">
              <h3>${escapeHtml(article.headline || "Untitled")}</h3>
              <p>${escapeHtml(article.description || "")}</p>
            </div>
          </a>
        `).join("")}
      </div>
    </div>
  `;
}

function renderSheetSkeleton(event) {
  const competition = event.competitions?.[0] ?? {};
  const teams = normalizeCompetitors(competition.competitors);
  return `
    <div class="sheet-scoreboard">
      <div class="sheet-teams">
        <div class="sheet-team">
          <img src="${teams.home.logo}" alt="" />
          <strong>${escapeHtml(teams.home.displayName)}</strong>
        </div>
        <div class="sheet-score">
          <strong>${escapeHtml(getScoreText(teams, event))}</strong>
          <span>${escapeHtml(event.status?.type?.shortDetail || "Match")}</span>
        </div>
        <div class="sheet-team">
          <img src="${teams.away.logo}" alt="" />
          <strong>${escapeHtml(teams.away.displayName)}</strong>
        </div>
      </div>
    </div>
  `;
}

function renderMatchSheet(event, summary, competitionData = null) {
  const competition = event.competitions?.[0] ?? {};
  const teams = normalizeCompetitors(competition.competitors);
  const venue = summary?.gameInfo?.venue?.fullName || event.venue?.displayName || "Venue TBA";
  const city = summary?.gameInfo?.venue?.address?.city;
  const teamStats = summary?.boxscore?.teams ?? [];
  const form = summary?.boxscore?.form ?? [];
  const articles = (summary?.news?.articles ?? []).slice(0, 3);
  const timeline = getTimelineEvents(summary);

  return `
    ${renderSheetSkeleton(event)}
    <p class="sheet-subtitle">${escapeHtml(formatFullDate(event.date))} - ${escapeHtml(venue)}${city ? `, ${escapeHtml(city)}` : ""}</p>
    <div class="detail-grid">
      ${renderOdds(summary?.odds, teams)}
      ${renderTimeline(timeline)}
      ${renderMatchStats(teamStats)}
      ${renderLineups(summary?.rosters, competitionData)}
      ${renderTeamStats(teamStats)}
      ${renderRecentForm(form)}
      ${renderMatchNews(articles)}
      <div class="detail-block">
        <h3>ESPN links</h3>
        <div class="match-meta">
          <i data-lucide="external-link"></i>
          <span>${event.links?.[0]?.href ? `<a href="${event.links[0].href}" target="_blank" rel="noopener noreferrer">Open match center</a>` : "No ESPN link available"}</span>
        </div>
      </div>
    </div>
  `;
}

function renderMatchStats(teamStats) {
  if (!Array.isArray(teamStats) || teamStats.length < 2) {
    return "";
  }

  const homeStats = normalizeStatList(teamStats[0]?.statistics);
  const awayStats = normalizeStatList(teamStats[1]?.statistics);
  const rows = [
    { label: "Possession", name: "possessionPct", suffix: "%" },
    { label: "Shots", name: "totalShots" },
    { label: "On target", name: "shotsOnTarget" },
    { label: "Corners", name: "wonCorners" },
    { label: "Fouls", name: "foulsCommitted" },
    { label: "Yellow cards", name: "yellowCards" },
    { label: "Red cards", name: "redCards" },
  ].map((item) => buildMatchStatRow(item, homeStats, awayStats)).filter(Boolean);

  if (!rows.length) {
    return "";
  }

  return `
    <div class="detail-block">
      <h3>Match stats</h3>
      <div class="match-stats-list">
        ${rows.join("")}
      </div>
      <p class="stats-note">Stats are shown when ESPN publishes official match data.</p>
    </div>
  `;
}

function buildMatchStatRow(item, homeStats, awayStats) {
  const home = homeStats.get(item.name);
  const away = awayStats.get(item.name);
  if (!home || !away) return "";

  const homeValue = parseStatNumber(home.displayValue);
  const awayValue = parseStatNumber(away.displayValue);
  const total = homeValue + awayValue;
  const homePct = total > 0 ? (homeValue / total) * 100 : 50;
  const awayPct = total > 0 ? (awayValue / total) * 100 : 50;

  return `
    <div class="match-stat">
      <span class="match-stat-value">${escapeHtml(formatStatDisplay(home.displayValue, item.suffix))}</span>
      <div class="match-stat-mid">
        <span class="match-stat-label">${escapeHtml(item.label)}</span>
        <div class="match-stat-bar" style="--home:${homePct}%;--away:${awayPct}%">
          <span></span><span></span>
        </div>
      </div>
      <span class="match-stat-value">${escapeHtml(formatStatDisplay(away.displayValue, item.suffix))}</span>
    </div>
  `;
}

function parseStatNumber(value) {
  const parsed = Number(String(value ?? "").replace("%", ""));
  return Number.isFinite(parsed) ? Math.max(parsed, 0) : 0;
}

function formatStatDisplay(value, suffix = "") {
  if (value === undefined || value === null || value === "") return "-";
  const text = String(value);
  if (suffix && !text.includes(suffix)) return `${text}${suffix}`;
  return text;
}

function renderLineups(rosters = [], competitionData = null) {
  const teams = rosters.filter((group) => group?.roster?.length);
  if (!teams.length) return "";
  const orderedTeams = [...teams].sort((a, b) => {
    if (a.homeAway === b.homeAway) return 0;
    return a.homeAway === "away" ? -1 : 1;
  });

  return `
    <div class="detail-block">
      <h3>Lineups</h3>
      <div class="lineup-terrain">
        ${renderFieldMarkings()}
        <div class="lineup-players-layer">
          ${orderedTeams.map((group) => renderLineupTeam(group, competitionData)).join("")}
        </div>
      </div>
      <div class="lineup-bench-list">
        ${orderedTeams.map(renderLineupBench).join("")}
      </div>
    </div>
  `;
}

function renderFieldMarkings() {
  return `
    <div class="lineup-field-parts" aria-hidden="true">
      <div class="field-halfway-line"></div>
      <div class="field-goal field-goal-top">
        <svg viewBox="0 0 160 70" width="160" height="70">
          <g stroke="currentColor" fill="transparent" stroke-width="2">
            <rect x="1" y="0" width="158" height="46"></rect>
            <rect x="42" y="0" width="74" height="24"></rect>
            <path d="M 39 46 A 50 50 0 0 0 119 46"></path>
          </g>
        </svg>
      </div>
      <div class="field-goal field-goal-bottom">
        <svg viewBox="0 0 160 70" width="160" height="70">
          <g stroke="currentColor" fill="transparent" stroke-width="2">
            <rect x="1" y="0" width="158" height="46"></rect>
            <rect x="42" y="0" width="74" height="24"></rect>
            <path d="M 39 46 A 50 50 0 0 0 119 46"></path>
          </g>
        </svg>
      </div>
      <div class="field-center-circle">
        <svg viewBox="0 0 128 128" width="128" height="128">
          <circle stroke="currentColor" fill="transparent" stroke-width="2" cx="64" cy="64" r="62"></circle>
        </svg>
      </div>
      <div class="field-corner field-corner-top-left">
        <svg viewBox="0 0 14 14" width="14" height="14">
          <circle stroke="currentColor" fill="transparent" stroke-width="2" cx="0" cy="0" r="12"></circle>
        </svg>
      </div>
      <div class="field-corner field-corner-top-right">
        <svg viewBox="0 0 14 14" width="14" height="14">
          <circle stroke="currentColor" fill="transparent" stroke-width="2" cx="14" cy="0" r="12"></circle>
        </svg>
      </div>
      <div class="field-corner field-corner-bottom-left">
        <svg viewBox="0 0 14 14" width="14" height="14">
          <circle stroke="currentColor" fill="transparent" stroke-width="2" cx="0" cy="14" r="12"></circle>
        </svg>
      </div>
      <div class="field-corner field-corner-bottom-right">
        <svg viewBox="0 0 14 14" width="14" height="14">
          <circle stroke="currentColor" fill="transparent" stroke-width="2" cx="14" cy="14" r="12"></circle>
        </svg>
      </div>
    </div>
  `;
}

function renderLineupTeam(group, competitionData = null) {
  const starters = group.roster.filter((player) => player.starter);
  const rows = buildFormationRows(starters, group.formation);
  const side = group.homeAway === "home" ? "home" : "away";
  const team = {
    ...(group.team ?? {}),
    uniform: getEventUniform(group, competitionData),
  };

  return `
    <div class="team-lineup-half ${side}">
      <div class="lineup-team-tag ${side}">
        <span>${escapeHtml(group.team?.abbreviation || "")}</span>
        <strong>${escapeHtml(group.formation || "TBA")}</strong>
      </div>
      ${rows.map((row) => renderFormationRow(row, side, team)).join("")}
    </div>
  `;
}

function renderFormationRow(row, side, team) {
  return `
    <div class="formation-row ${side === "away" ? "row-reverse" : ""}" data-line="${escapeHtml(row.line)}">
      ${row.players.map((player, index) => renderPlayerNode(player, row.line, index, row.players.length, team)).join("")}
    </div>
  `;
}

function renderPlayerNode(player, rowLine, index, count, team = {}) {
  const name = player.athlete?.shortName || player.athlete?.displayName || "Player";
  const position = getPlayerPositionLabel(player, rowLine, index, count);
  const rating = getPlayerRating(player);
  const jersey = buildPlayerJersey(player, team);

  return `
    <div class="player-node">
      <div class="player-jersey-wrap" style="--jersey:${escapeHtml(jersey.primary)};--jersey-alt:${escapeHtml(jersey.accent)};--jersey-text:${escapeHtml(jersey.text)}">
        <span class="player-jersey" aria-label="${escapeHtml(`${name} jersey ${jersey.number}`)}">
          <span>${escapeHtml(jersey.number)}</span>
        </span>
        ${rating ? `<span class="player-rating" style="background:${getRatingColor(rating)}">${escapeHtml(rating)}</span>` : ""}
      </div>
      <span class="player-position">${escapeHtml(position)}</span>
      <span class="player-name"><span class="player-number">${escapeHtml(player.jersey || "")}</span>${escapeHtml(name)}</span>
    </div>
  `;
}

function renderLineupBench(group) {
  const bench = group.roster.filter((player) => !player.starter);
  if (!bench.length) return "";

  return `
    <div class="lineup-bench">
      <div class="lineup-heading">
        <span>${escapeHtml(group.team?.abbreviation || "")}</span>
        <strong>${escapeHtml(group.team?.displayName || "Team")}</strong>
        <em>Bench</em>
      </div>
      <div class="player-list">
        ${bench.map((player) => {
          const name = player.athlete?.shortName || player.athlete?.displayName || "Player";
          return `
            <div class="player-row">
              <span class="player-number">${escapeHtml(player.jersey || "-")}</span>
              <div>
                <strong>${escapeHtml(name)}</strong>
                <span>${escapeHtml(getPlayerPositionLabel(player, "bench", 0, 1))}</span>
              </div>
              ${player.subbedIn ? `<em>IN</em>` : player.subbedOut ? `<em>OUT</em>` : ""}
            </div>
          `;
        }).join("")}
      </div>
    </div>
  `;
}

function buildFormationRows(starters, formation) {
  const byPosition = buildFormationRowsFromPositions(starters);
  if (byPosition.length >= 3) {
    return byPosition;
  }

  const ordered = [...starters].sort((a, b) => Number(a.formationPlace || 99) - Number(b.formationPlace || 99));
  const counts = parseFormationCounts(formation, ordered.length);
  let cursor = 0;

  return counts.map((count, index) => {
    const line = getFormationLineName(index, counts.length);
    const players = ordered.slice(cursor, cursor + count).sort((a, b) => getPositionSortWeight(a) - getPositionSortWeight(b));
    cursor += count;
    return { line, players };
  }).filter((row) => row.players.length);
}

function buildFormationRowsFromPositions(starters) {
  const buckets = {
    goalkeeper: [],
    defenders: [],
    midfielders: [],
    "attacking-midfielders": [],
    forwards: [],
  };

  starters.forEach((player) => {
    buckets[getPlayerLine(player)]?.push(player);
  });

  return ["goalkeeper", "defenders", "midfielders", "attacking-midfielders", "forwards"]
    .map((line) => ({
      line,
      players: buckets[line].sort((a, b) => getPositionSortWeight(a) - getPositionSortWeight(b)),
    }))
    .filter((row) => row.players.length);
}

function getPlayerLine(player) {
  const label = normalizePositionLabel(player.position?.abbreviation, player.position?.displayName);
  if (label === "GK") return "goalkeeper";
  if (["LB", "LWB", "LCB", "CB", "RCB", "RB", "RWB"].includes(label)) return "defenders";
  if (["CDM", "LCM", "CM", "RCM", "LM", "RM"].includes(label)) return "midfielders";
  if (["LW", "CAM", "RW"].includes(label)) return "attacking-midfielders";
  if (["ST", "CF"].includes(label)) return "forwards";

  const text = String(player.position?.displayName || "").toLowerCase();
  if (text.includes("goalkeeper")) return "goalkeeper";
  if (text.includes("back") || text.includes("defender")) return "defenders";
  if (text.includes("attacking midfielder") || text.includes("winger")) return "attacking-midfielders";
  if (text.includes("midfielder")) return "midfielders";
  if (text.includes("forward") || text.includes("striker")) return "forwards";
  return "midfielders";
}

function parseFormationCounts(formation, starterCount) {
  const parts = String(formation || "")
    .split("-")
    .map((part) => Number(part))
    .filter((value) => Number.isFinite(value) && value > 0);
  const counts = [1, ...parts];
  const total = counts.reduce((sum, value) => sum + value, 0);

  if (total === starterCount) return counts;
  if (starterCount === 11) return [1, 4, 3, 3];
  return [1, Math.max(starterCount - 1, 0)].filter(Boolean);
}

function getFormationLineName(index, totalRows) {
  if (index === 0) return "goalkeeper";
  if (index === 1) return "defenders";
  if (index === totalRows - 1) return "forwards";
  if (totalRows >= 5 && index === totalRows - 2) return "attacking-midfielders";
  return "midfielders";
}

function getPlayerPositionLabel(player, rowLine, index, count) {
  const exact = normalizePositionLabel(player.position?.abbreviation, player.position?.displayName);
  if (exact && exact !== "SUB") return exact;
  return inferPositionLabel(rowLine, index, count);
}

function normalizePositionLabel(abbreviation = "", displayName = "") {
  const raw = String(abbreviation || displayName || "").toUpperCase();
  const text = String(displayName || "").toLowerCase();
  const map = {
    G: "GK",
    GK: "GK",
    "D-L": "LB",
    "D-R": "RB",
    "D-C": "CB",
    "CD-L": "LCB",
    "CD-C": "CB",
    "CD-R": "RCB",
    "M-L": "LM",
    "M-C": "CM",
    "M-R": "RM",
    "DM-C": "CDM",
    "AM-L": "LW",
    "AM-C": "CAM",
    "AM-R": "RW",
    "F-L": "LW",
    "F-C": "ST",
    "F-R": "RW",
    F: "ST",
    CF: "ST",
    "CF-L": "ST",
    "CF-R": "ST",
    AM: "CAM",
    LB: "LB",
    RB: "RB",
    CD: "CB",
  };
  if (map[raw]) return map[raw];
  if (text.includes("goalkeeper")) return "GK";
  if (text.includes("left back")) return "LB";
  if (text.includes("right back")) return "RB";
  if (text.includes("center left defender")) return "LCB";
  if (text.includes("center right defender")) return "RCB";
  if (text.includes("defender")) return "CB";
  if (text.includes("defensive midfielder")) return "CDM";
  if (text.includes("attacking midfielder")) return "CAM";
  if (text.includes("left midfielder")) return "LM";
  if (text.includes("right midfielder")) return "RM";
  if (text.includes("midfielder")) return "CM";
  if (text.includes("left winger")) return "LW";
  if (text.includes("right winger")) return "RW";
  if (text.includes("forward") || text.includes("striker")) return "ST";
  return raw;
}

function inferPositionLabel(rowLine, index, count) {
  const labels = {
    goalkeeper: ["GK"],
    defenders: {
      3: ["LCB", "CB", "RCB"],
      4: ["LB", "CB", "CB", "RB"],
      5: ["LWB", "CB", "CB", "CB", "RWB"],
    },
    midfielders: {
      1: ["CDM"],
      2: ["CM", "CM"],
      3: ["LCM", "CM", "RCM"],
      4: ["LM", "CM", "CM", "RM"],
      5: ["LM", "CM", "CM", "CM", "RM"],
    },
    "attacking-midfielders": {
      1: ["CAM"],
      2: ["CAM", "CAM"],
      3: ["LW", "CAM", "RW"],
      4: ["LW", "CAM", "CAM", "RW"],
    },
    forwards: {
      1: ["ST"],
      2: ["ST", "ST"],
      3: ["LW", "ST", "RW"],
    },
  };
  const rowLabels = labels[rowLine];
  if (Array.isArray(rowLabels)) return rowLabels[index] || rowLabels[0] || "";
  return rowLabels?.[count]?.[index] || "";
}

function getPositionSortWeight(player) {
  const label = normalizePositionLabel(player.position?.abbreviation, player.position?.displayName);
  const order = {
    LWB: 0,
    LB: 1,
    LW: 2,
    LM: 3,
    LCB: 4,
    LCM: 5,
    CDM: 6,
    CB: 7,
    CM: 8,
    CAM: 9,
    ST: 10,
    RCM: 11,
    RCB: 12,
    RM: 13,
    RW: 14,
    RB: 15,
    RWB: 16,
  };
  return order[label] ?? 8;
}

function getPlayerRating(player) {
  const rating = player.stats?.find((stat) => ["rating", "matchRating"].includes(stat.name))?.displayValue;
  return rating ? Number(rating).toFixed(1) : "";
}

function buildPlayerJersey(player, team = {}) {
  const uniform = team.uniform ?? {};
  const primary = normalizeHexColor(uniform.color || team.color, "1f8f55");
  const accent = normalizeHexColor(uniform.alternateColor || team.alternateColor, "ffffff");
  return {
    number: player.jersey || player.athlete?.jersey || "-",
    type: uniform.type || "",
    primary: `#${primary}`,
    accent: `#${accent}`,
    text: getReadableTextColor(primary),
  };
}

function getEventUniform(group, competitionData) {
  const teamId = String(group.team?.id || group.id || "");
  const homeAway = group.homeAway || "";
  const competitor = (competitionData?.competitors ?? []).find((item) => {
    return String(item.id || "") === teamId || (homeAway && item.homeAway === homeAway);
  });
  return competitor?.uniform ?? null;
}

function normalizeHexColor(value, fallback) {
  const color = String(value || "").replace("#", "").trim();
  return /^[0-9a-f]{6}$/i.test(color) ? color : fallback;
}

function getReadableTextColor(hex) {
  const red = parseInt(hex.slice(0, 2), 16);
  const green = parseInt(hex.slice(2, 4), 16);
  const blue = parseInt(hex.slice(4, 6), 16);
  const luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;
  return luminance > 0.58 ? "#07130e" : "#ffffff";
}

function getRatingColor(rating) {
  const value = Number(rating);
  if (value >= 8) return "#00adc4";
  if (value >= 7) return "#00c424";
  if (value >= 6.5) return "#d9af00";
  if (value >= 6) return "#ed7e07";
  return "#dc0c00";
}

function getInitials(name) {
  return String(name)
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

function renderLineupGroup(title, players) {
  if (!players.length) return "";

  return `
    <div class="lineup-group">
      <p class="sheet-subtitle">${escapeHtml(title)}</p>
      <div class="player-list">
        ${players.map((player) => `
          <div class="player-row">
            <span class="player-number">${escapeHtml(player.jersey || "-")}</span>
            <div>
              <strong>${escapeHtml(player.athlete?.shortName || player.athlete?.displayName || "Player")}</strong>
              <span>${escapeHtml(player.position?.abbreviation || player.position?.displayName || "")}</span>
            </div>
            ${player.subbedIn ? `<em>IN</em>` : player.subbedOut ? `<em>OUT</em>` : ""}
          </div>
        `).join("")}
      </div>
    </div>
  `;
}

function renderOdds(oddsList = [], teams) {
  const odds = pickOddsProvider(oddsList);
  if (!odds) return "";

  const providerLogo = odds.provider?.logos?.find((logo) => logo.rel?.includes("dark"))?.href
    || odds.header?.logo?.dark
    || odds.provider?.logos?.[0]?.href
    || "";
  const providerName = odds.provider?.name || odds.header?.text || "Odds";
  const providerMark = renderProviderMark(providerName, providerLogo);
  const homeOdds = formatDecimalOdds(
    odds.moneyline?.home?.close?.odds
      ?? odds.homeTeamOdds?.moneyLine
      ?? odds.homeTeamOdds?.odds?.summary
  );
  const drawOdds = formatDecimalOdds(
    odds.moneyline?.draw?.close?.odds
      ?? odds.drawOdds?.moneyLine
      ?? odds.drawOdds?.summary
  );
  const awayOdds = formatDecimalOdds(
    odds.moneyline?.away?.close?.odds
      ?? odds.awayTeamOdds?.moneyLine
      ?? odds.awayTeamOdds?.odds?.summary
  );
  const spread = formatMarket(
    "Spread",
    odds.pointSpread?.home?.close?.line && odds.pointSpread?.away?.close?.line
      ? `${teams.home.abbreviation || "Home"} ${formatLineWithOdds(odds.pointSpread.home.close.line, odds.pointSpread.home.close.odds)} / ${teams.away.abbreviation || "Away"} ${formatLineWithOdds(odds.pointSpread.away.close.line, odds.pointSpread.away.close.odds)}`
      : odds.details
  );
  const total = formatMarket(
    "Total",
    odds.total?.over?.close?.line && odds.total?.under?.close?.line
      ? `${formatLineWithOdds(odds.total.over.close.line, odds.total.over.close.odds)} / ${formatLineWithOdds(odds.total.under.close.line, odds.total.under.close.odds)}`
      : odds.overUnder
        ? `O/U ${odds.overUnder}`
        : ""
  );
  const disclaimer = getFirstLine(odds.footer?.disclaimer);

  if (!homeOdds && !drawOdds && !awayOdds && !spread.value && !total.value) {
    return "";
  }

  return `
    <div class="detail-block">
      <h3>Odds</h3>
      <div class="odds-board">
        <div class="odds-provider">
          <span>${escapeHtml(providerName)}</span>
          ${providerMark}
        </div>
        <div class="odds-grid">
          <div class="odds-cell">
            <span>${escapeHtml(teams.home.abbreviation || "Home")}</span>
            <strong>${escapeHtml(homeOdds || "-")}</strong>
          </div>
          <div class="odds-cell">
            <span>Draw</span>
            <strong>${escapeHtml(drawOdds || "-")}</strong>
          </div>
          <div class="odds-cell">
            <span>${escapeHtml(teams.away.abbreviation || "Away")}</span>
            <strong>${escapeHtml(awayOdds || "-")}</strong>
          </div>
        </div>
        ${spread.value ? `<div class="market-row"><span>${escapeHtml(spread.label)}</span><strong>${escapeHtml(spread.value)}</strong></div>` : ""}
        ${total.value ? `<div class="market-row"><span>${escapeHtml(total.label)}</span><strong>${escapeHtml(total.value)}</strong></div>` : ""}
        ${disclaimer ? `<p class="odds-disclaimer">${escapeHtml(disclaimer)}</p>` : ""}
      </div>
    </div>
  `;
}

function renderProviderMark(providerName, providerLogo) {
  if (providerLogo) {
    return `<img src="${providerLogo}" alt="" loading="lazy" />`;
  }

  if (String(providerName).toLowerCase().includes("bet 365")) {
    return `<span class="provider-wordmark">bet<span>365</span></span>`;
  }

  return "";
}

function pickOddsProvider(oddsList = []) {
  if (!Array.isArray(oddsList) || !oddsList.length) return null;

  const usableOdds = oddsList.filter((odds) => odds.homeTeamOdds || odds.awayTeamOdds || odds.drawOdds || odds.moneyline);
  const named = (needle) => usableOdds.find((odds) => {
    const providerName = String(odds.provider?.name || odds.header?.text || "").toLowerCase();
    return providerName.includes(needle);
  });

  return named("bet 365")
    || named("bet365")
    || usableOdds.find((odds) => {
      const providerName = String(odds.provider?.name || odds.header?.text || "").toLowerCase();
      return providerName && !providerName.includes("draftkings");
    })
    || usableOdds.find((odds) => odds.moneyline || odds.pointSpread || odds.total)
    || usableOdds[0]
    || null;
}

function formatDecimalOdds(value) {
  if (value === undefined || value === null || value === "") return "";
  if (typeof value === "number") {
    return formatDecimalNumber(americanToDecimal(value));
  }

  const trimmed = String(value).trim();
  if (!trimmed) return "";
  if (/^[+-]\d+(\.\d+)?$/.test(trimmed)) {
    return formatDecimalNumber(americanToDecimal(Number(trimmed)));
  }
  if (/^\d+\/\d+$/.test(trimmed)) {
    const [numerator, denominator] = trimmed.split("/").map(Number);
    if (denominator) return formatDecimalNumber(1 + numerator / denominator);
  }
  if (/^\d+(\.\d+)?$/.test(trimmed)) {
    return formatDecimalNumber(Number(trimmed));
  }
  return trimmed;
}

function americanToDecimal(value) {
  return value > 0 ? 1 + value / 100 : 1 + 100 / Math.abs(value);
}

function formatDecimalNumber(value) {
  if (!Number.isFinite(value)) return "";
  return value < 1.01 ? value.toFixed(3) : value.toFixed(2);
}

function formatLineWithOdds(line, odds) {
  const decimalOdds = formatDecimalOdds(odds);
  return `${line || ""}${decimalOdds ? ` ${decimalOdds}` : ""}`.trim();
}

function formatMarket(label, value) {
  return { label, value: value === undefined || value === null ? "" : String(value).trim() };
}

function getFirstLine(value) {
  return String(value || "").split("\n").find(Boolean) || "";
}

function renderTimeline(events) {
  if (!events.length) {
    return `
      <div class="detail-block">
        <h3>Timeline</h3>
        ${emptyState("No timeline yet", "ESPN has not published match events for this fixture.")}
      </div>
    `;
  }

  return `
    <div class="detail-block">
      <h3>Timeline</h3>
      <div class="timeline-list">
        ${events.map(renderTimelineItem).join("")}
      </div>
    </div>
  `;
}

function renderTimelineItem(event) {
  const meta = timelineMeta(event);
  const title = event.shortText || event.type?.text || "Match event";
  const detail = event.text && event.text !== title ? event.text : "";
  const teamName = event.team?.displayName || "";

  return `
    <div class="timeline-item ${meta.className}">
      <span class="timeline-minute">${escapeHtml(event.clock?.displayValue || event.time?.displayValue || "")}</span>
      <span class="timeline-icon"><i data-lucide="${meta.icon}"></i></span>
      <div class="timeline-copy">
        <strong>${escapeHtml(title)}</strong>
        ${detail ? `<p>${escapeHtml(detail)}</p>` : ""}
        ${teamName ? `<span class="timeline-team">${escapeHtml(teamName)}</span>` : ""}
      </div>
    </div>
  `;
}

function getTimelineEvents(summary) {
  const keyEvents = normalizeTimelineEvents(summary?.keyEvents);
  if (keyEvents.length) {
    return keyEvents;
  }

  const importantTypes = new Set([
    "goal",
    "goal---free-kick",
    "goal---header",
    "goal---penalty",
    "goal---own-goal",
    "penalty---scored",
    "yellow-card",
    "red-card",
    "second-yellow-card",
    "substitution",
    "deleted-after-review",
    "var---referee-decision-cancelled",
    "var---goal-awarded",
    "var---penalty-awarded",
    "var---penalty-not-awarded",
    "kickoff",
    "halftime",
    "start-2nd-half",
    "end-regular-time",
  ]);

  const commentaryEvents = (summary?.commentary ?? [])
    .map((item) => item.play ? { ...item.play, clock: item.play.clock || item.time } : null)
    .filter((play) => play && importantTypes.has(play.type?.type));

  return normalizeTimelineEvents(commentaryEvents);
}

function normalizeTimelineEvents(events = []) {
  const seen = new Set();
  return events
    .filter((event) => event?.type?.type)
    .filter((event) => {
      const key = event.id || `${event.type.type}:${event.clock?.value}:${event.text}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => {
      const aClock = Number(a.clock?.value ?? a.time?.value ?? 0);
      const bClock = Number(b.clock?.value ?? b.time?.value ?? 0);
      if (aClock !== bClock) return aClock - bClock;
      return String(a.id || "").localeCompare(String(b.id || ""));
    });
}

function timelineMeta(event) {
  const type = event.type?.type || "";
  const label = `${type} ${event.type?.text || ""} ${event.text || ""}`.toLowerCase();

  if (label.includes("var") || type.includes("review") || type.includes("deleted-after-review")) {
    return { icon: "scan-search", className: "var" };
  }
  if (type.includes("goal") || event.scoringPlay) {
    return { icon: "circle-dot", className: "goal" };
  }
  if (type.includes("red-card") || type.includes("second-yellow")) {
    return { icon: "badge-alert", className: "red-card" };
  }
  if (type.includes("yellow-card")) {
    return { icon: "badge-alert", className: "card" };
  }
  if (type.includes("substitution")) {
    return { icon: "replace", className: "substitution" };
  }
  if (type.includes("half") || type.includes("kickoff") || type.includes("end-regular-time")) {
    return { icon: "timer", className: "time" };
  }
  return { icon: "dot", className: "event" };
}

function renderTeamStats(teamStats) {
  if (teamStats.length < 2) {
    return "";
  }

  const homeStats = normalizeStatList(teamStats[0]?.statistics);
  const awayStats = normalizeStatList(teamStats[1]?.statistics);
  const labels = ["totalGoals", "goalAssists", "goalsConceded", "goalDifference"];
  const rows = labels.map((name) => {
    const home = homeStats.get(name);
    const away = awayStats.get(name);
    if (!home || !away) return "";
    const homeNumber = Math.max(Number(home.displayValue) || 0, 0);
    const awayNumber = Math.max(Number(away.displayValue) || 0, 0);
    const total = homeNumber + awayNumber || 1;
    return `
      <div class="stat-row">
        <strong>${escapeHtml(home.displayValue)}</strong>
        <div>
          <span>${escapeHtml(home.label || home.name)}</span>
          <div class="stat-bar" style="--home:${(homeNumber / total) * 100}%;--away:${(awayNumber / total) * 100}%">
            <span></span><span></span>
          </div>
        </div>
        <strong>${escapeHtml(away.displayValue)}</strong>
      </div>
    `;
  }).join("");

  if (!rows.trim()) return "";

  return `
    <div class="detail-block">
      <h3>Season stats</h3>
      ${rows}
    </div>
  `;
}

function renderRecentForm(formGroups) {
  const usable = (formGroups ?? []).filter((group) => group.events?.length);
  if (!usable.length) return "";

  return `
    <div class="detail-block">
      <h3>Recent form</h3>
      ${usable.map((group) => `
        <p class="sheet-subtitle">${escapeHtml(group.team?.displayName || "Team")}</p>
        <div class="event-strip">
          ${group.events.slice(0, 5).map((item) => {
            const result = String(item.gameResult || "").toUpperCase();
            const cls = result === "W" ? "win" : result === "L" ? "loss" : "draw";
            return `<span class="form-pill ${cls}" title="${escapeHtml(item.score || "")}">${escapeHtml(result || "-")}</span>`;
          }).join("")}
        </div>
      `).join("")}
    </div>
  `;
}

function renderMatchNews(articles) {
  if (!articles.length) return "";

  return `
    <div class="detail-block">
      <h3>Related news</h3>
      <div class="news-list">
        ${articles.map((article) => `
          <a class="news-card" href="${article.links?.web?.href || "#"}" target="_blank" rel="noopener noreferrer">
            <div class="news-copy">
              <h3>${escapeHtml(article.headline || "Untitled")}</h3>
              <p>${escapeHtml(article.description || "")}</p>
            </div>
          </a>
        `).join("")}
      </div>
    </div>
  `;
}

function renderError(error) {
  const message = error?.message || "The ESPN request failed.";
  els.matchesList.innerHTML = emptyState("Could not load scores", message);
  els.standingsList.innerHTML = emptyState("Could not load standings", message);
  els.newsList.innerHTML = emptyState("Could not load news", message);
  els.syncLabel.textContent = "ESPN error";
}

function renderPanelError(target, title, error) {
  target.innerHTML = emptyState(title, error?.message || "The ESPN request failed.");
}

function emptyState(title, detail) {
  return `<div class="state-card"><strong>${escapeHtml(title)}</strong>${escapeHtml(detail)}</div>`;
}

function setLoading(isLoading) {
  els.refreshButton.disabled = isLoading;
  els.refreshButton.style.opacity = isLoading ? "0.55" : "1";
  els.appShell?.setAttribute("aria-busy", isLoading ? "true" : "false");
  els.syncLabel.textContent = isLoading ? "Loading ESPN" : els.syncLabel.textContent;
}

function finishInitialLoad() {
  if (state.hasCompletedInitialLoad) return;
  state.hasCompletedInitialLoad = true;
  document.body.classList.remove("is-app-loading");
  els.appLoader?.setAttribute("aria-hidden", "true");
}

function setSyncLabel() {
  const now = new Date();
  els.syncLabel.textContent = `Updated ${now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
}

function getLeague() {
  return LEAGUES.find((league) => league.id === state.leagueId) ?? LEAGUES[0];
}

function getLeagueName() {
  return state.scoreboard?.leagues?.[0]?.abbreviation || state.standings?.abbreviation || getLeague().name;
}

function getSeasonLabel() {
  return state.scoreboard?.leagues?.[0]?.season?.displayName
    || state.standings?.season?.displayName
    || `${getLeague().country} competition`;
}

function getStandingsEntries() {
  return getStandingsEntriesFrom(state.standings);
}

function normalizeCompetitors(competitors = []) {
  const fallback = {
    displayName: "TBA",
    abbreviation: "-",
    score: "-",
    logo: "",
    record: "",
  };
  const mapped = competitors.map((competitor) => {
    const team = competitor.team ?? {};
    return {
      id: team.id || "",
      displayName: team.shortDisplayName || team.displayName || team.name || "TBA",
      abbreviation: team.abbreviation || "",
      score: competitor.score ?? "-",
      logo: getTeamLogo(team),
      record: competitor.records?.[0]?.summary || "",
      homeAway: competitor.homeAway,
    };
  });

  return {
    home: mapped.find((team) => team.homeAway === "home") ?? mapped[0] ?? fallback,
    away: mapped.find((team) => team.homeAway === "away") ?? mapped[1] ?? fallback,
  };
}

function getTeamLogo(team = {}) {
  return team.logo || team.logos?.[0]?.href || "";
}

function getScoreText(teams, event) {
  if (event.status?.type?.state === "pre") {
    return formatTime(event.date);
  }
  return `${teams.home.score ?? "-"}-${teams.away.score ?? "-"}`;
}

function statMap(stats = []) {
  return new Map(stats.map((stat) => [stat.name, stat]));
}

function pickStat(stats, name) {
  return stats.get(name)?.displayValue ?? stats.get(name)?.value ?? "";
}

function normalizeStatList(stats = []) {
  return new Map(stats.map((stat) => [stat.name, stat]));
}

function isLive(statusState) {
  return statusState === "in";
}

function formatApiDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}${month}${day}`;
}

function toDateInputValue(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function fromDateInputValue(value) {
  const [year, month, day] = value.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function fromApiDay(value) {
  const [year, month, day] = value.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function formatDateLabel(date) {
  return date.toLocaleDateString([], {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

function ordinal(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return String(value || "");
  const suffixes = ["th", "st", "nd", "rd"];
  const mod100 = number % 100;
  const suffix = suffixes[(mod100 - 20) % 10] || suffixes[mod100] || suffixes[0];
  return `${number}${suffix}`;
}

function formatFullDate(value) {
  return new Date(value).toLocaleString([], {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function formatTime(value) {
  if (!value) return "TBA";
  return new Date(value).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function formatRelativeDate(value) {
  if (!value) return "";
  const date = new Date(value);
  const diff = Date.now() - date.getTime();
  const minutes = Math.round(diff / 60000);
  if (minutes < 60) return `${Math.max(minutes, 1)}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return date.toLocaleDateString([], { month: "short", day: "numeric" });
}

function isSameLocalDay(a, b) {
  return a.getFullYear() === b.getFullYear()
    && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate();
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function escapeSelectorValue(value) {
  if (window.CSS?.escape) {
    return window.CSS.escape(String(value));
  }
  return String(value).replace(/["\\]/g, "\\$&");
}

function hydrateIcons() {
  if (window.lucide) {
    window.lucide.createIcons();
  }
}
