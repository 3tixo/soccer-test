import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScoreboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pitchBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        leagueStrip
                        hero
                        matchSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("SOCCER LIVE CENTER")
                .font(.caption2.weight(.black))
                .foregroundStyle(Color.pitchAccent)
            Text("PitchPulse")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
    }

    private var leagueStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(nativeLeagues) { league in
                    Button {
                        viewModel.select(league)
                    } label: {
                        Text(league.name)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(viewModel.selectedLeague == league ? Color.pitchBackground : .white)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(viewModel.selectedLeague == league ? Color.pitchAccent : Color.pitchSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedLeague.country.uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(.secondary)
            Text(viewModel.selectedLeague.name)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                stat(label: "Matches", value: "\(viewModel.events.count)")
                stat(label: "Live", value: "\(viewModel.events.filter { $0.status?.type?.state == "in" }.count)")
                stat(label: "League", value: viewModel.selectedLeague.id.uppercased())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pitchCard)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(minWidth: 78, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FIXTURES")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.pitchAccent)
                    Text("\(viewModel.selectedLeague.name) Matches")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color.pitchAccent)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                StateCard(title: "ESPN error", detail: errorMessage)
            } else if viewModel.events.isEmpty && !viewModel.isLoading {
                StateCard(title: "No matches", detail: "ESPN did not return fixtures for this league right now.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.events) { event in
                        MatchCard(event: event)
                    }
                }
            }
        }
    }
}

struct MatchCard: View {
    let event: ScoreEvent

    private var home: Competitor? {
        competitors.first(where: { $0.homeAway == "home" }) ?? competitors.first
    }

    private var away: Competitor? {
        competitors.first(where: { $0.homeAway == "away" }) ?? competitors.dropFirst().first
    }

    private var competitors: [Competitor] {
        event.competition?.competitors ?? []
    }

    private var isPre: Bool {
        event.status?.type?.state == "pre"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("MATCH")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(event.status?.type?.shortDetail ?? event.status?.type?.description ?? "Scheduled")
                    .font(.caption.weight(.black))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }

            teamLine(home)
            teamLine(away)

            if let venue = event.competition?.venue?.fullName ?? event.competition?.venue?.displayName {
                Text(venue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color.pitchSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusColor: Color {
        if event.status?.type?.state == "in" { return Color.pitchAccent }
        if event.status?.type?.completed == true { return .secondary }
        return .white
    }

    private func teamLine(_ competitor: Competitor?) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: competitor?.team?.logo ?? competitor?.team?.logos?.first?.href ?? "")) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Text(competitor?.team?.abbreviation ?? "-").font(.caption2.weight(.black)))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(competitor?.team?.shortDisplayName ?? competitor?.team?.displayName ?? "TBA")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(competitor?.records?.first?.summary ?? competitor?.team?.abbreviation ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(isPre ? competitor?.team?.abbreviation ?? "-" : competitor?.score ?? "-")
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

struct StateCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pitchSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension Color {
    static let pitchBackground = Color(red: 0.03, green: 0.08, blue: 0.06)
    static let pitchSurface = Color(red: 0.07, green: 0.15, blue: 0.11)
    static let pitchCard = Color(red: 0.04, green: 0.18, blue: 0.14)
    static let pitchAccent = Color(red: 0.18, green: 0.89, blue: 0.56)
}
