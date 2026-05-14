import SwiftUI

struct TeamDetailView: View {
    let context: TeamDetailContext
    let league: League

    private var standingStats: [String: StandingStat] {
        Dictionary(uniqueKeysWithValues: (context.standing?.stats ?? []).compactMap { stat in
            guard let name = stat.name else { return nil }
            return (name, stat)
        })
    }

    var body: some View {
        ZStack {
            Color.pitchBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    snapshot
                    formBlock
                    scheduleBlock
                    newsBlock
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            TeamBadge(team: context.team)
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(league.name.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.pitchAccent)
                Text(context.team.bestName)
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(standingSummary)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.pitchCard)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var snapshot: some View {
        DetailBlock(title: "Club") {
            HStack(spacing: 10) {
                clubTile(label: "Standing", value: standingSummary.isEmpty ? "-" : standingSummary)
                clubTile(label: "Record", value: recordSummary)
            }
        }
    }

    private func clubTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var formBlock: some View {
        DetailBlock(title: "Recent form") {
            let form = context.events
                .filter { $0.status?.type?.completed == true }
                .prefix(8)
                .map { result(for: $0) }

            if form.isEmpty {
                StateCard(title: "No form", detail: "No completed matches are loaded for this club on this date.")
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(form.enumerated()), id: \.offset) { _, result in
                        Text(result)
                            .font(.caption.weight(.black))
                            .foregroundStyle(formColor(result))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private var scheduleBlock: some View {
        DetailBlock(title: "Schedule") {
            if context.events.isEmpty {
                StateCard(title: "No matches", detail: "No loaded fixtures include this club.")
            } else {
                VStack(spacing: 8) {
                    ForEach(context.events.prefix(8)) { event in
                        scheduleRow(event)
                    }
                }
            }
        }
    }

    private var newsBlock: some View {
        DetailBlock(title: "Team news") {
            if context.articles.isEmpty {
                StateCard(title: "No team news", detail: "No loaded ESPN articles matched this club.")
            } else {
                VStack(spacing: 10) {
                    ForEach(context.articles.prefix(4)) { article in
                        NewsCard(article: article)
                    }
                }
            }
        }
    }

    private func scheduleRow(_ event: ScoreEvent) -> some View {
        let teams = event.matchTeams
        let opponent = teams.home?.team?.stableId == context.team.stableId ? teams.away : teams.home
        let prefix = teams.home?.team?.stableId == context.team.stableId ? "vs" : "@"
        let result = event.status?.type?.completed == true ? result(for: event) : kickoffTime(event.date)

        return HStack(spacing: 10) {
            Text(shortDate(event.date))
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text("\(prefix) \(opponent?.team?.bestName ?? "TBA")")
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text(result)
                .font(.caption.weight(.black))
                .foregroundStyle(formColor(result))
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var standingSummary: String {
        guard let rank = statValue("rank"), !rank.isEmpty else { return "" }
        return "\(ordinal(rank)) in \(league.name)"
    }

    private var recordSummary: String {
        let wins = statValue("wins") ?? "-"
        let ties = statValue("ties") ?? "-"
        let losses = statValue("losses") ?? "-"
        return "\(wins)-\(ties)-\(losses)"
    }

    private func statValue(_ name: String) -> String? {
        standingStats[name]?.displayValue ?? standingStats[name]?.summary ?? standingStats[name]?.value.map { String(Int($0)) }
    }

    private func result(for event: ScoreEvent) -> String {
        let competitors = event.competition?.competitors ?? []
        guard
            let team = competitors.first(where: { $0.team?.stableId == context.team.stableId }),
            let opponent = competitors.first(where: { $0.team?.stableId != context.team.stableId })
        else {
            return "-"
        }

        if team.winner == true { return "W" }
        if opponent.winner == true { return "L" }

        let teamScore = Int(team.score ?? "")
        let opponentScore = Int(opponent.score ?? "")
        if let teamScore, let opponentScore {
            if teamScore > opponentScore { return "W" }
            if teamScore < opponentScore { return "L" }
            return "D"
        }
        return "-"
    }

    private func formColor(_ result: String) -> Color {
        switch result {
        case "W": return Color.pitchAccent
        case "L": return .red
        case "D": return .yellow
        default: return .secondary
        }
    }
}
