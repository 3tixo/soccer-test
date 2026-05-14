import SwiftUI

struct LineupView: View {
    let groups: [RosterGroup]

    private var orderedGroups: [RosterGroup] {
        groups
            .filter { !($0.roster ?? []).isEmpty }
            .sorted { first, second in
                if first.homeAway == second.homeAway { return false }
                return first.homeAway == "away"
            }
    }

    var body: some View {
        VStack(spacing: 12) {
            if orderedGroups.isEmpty {
                StateCard(title: "No lineups", detail: "ESPN has not published lineups for this match.")
            } else {
                ZStack {
                    PitchMarkings()
                    VStack(spacing: 0) {
                        ForEach(orderedGroups) { group in
                            TeamLineupHalf(group: group)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .frame(minHeight: 690)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.11, blue: 0.10),
                            Color(red: 0.10, green: 0.13, blue: 0.13)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(spacing: 10) {
                    ForEach(orderedGroups) { group in
                        BenchList(group: group)
                    }
                }
            }
        }
    }
}

struct TeamLineupHalf: View {
    let group: RosterGroup

    private var rows: [FormationRow] {
        let built = formationRows(for: group.roster ?? [], formation: group.formation)
        return group.homeAway == "home" ? Array(built.reversed()) : built
    }

    var body: some View {
        ZStack(alignment: group.homeAway == "home" ? .bottomLeading : .topLeading) {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    FormationLine(row: row, reversePlayers: group.homeAway == "away", team: group.team)
                }
            }

            HStack(spacing: 4) {
                Text(group.team?.abbreviation ?? "")
                    .foregroundStyle(Color.pitchAccent)
                Text(group.formation ?? "TBA")
                    .foregroundStyle(.white)
            }
            .font(.caption2.weight(.black))
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Color.pitchBackground.opacity(0.75))
            .clipShape(Capsule())
            .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 335)
    }
}

struct FormationLine: View {
    let row: FormationRow
    let reversePlayers: Bool
    let team: Team?

    private var players: [RosterPlayer] {
        reversePlayers ? Array(row.players.reversed()) : row.players
    }

    var body: some View {
        HStack(alignment: .top) {
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                PlayerNode(
                    player: player,
                    position: positionLabel(for: player, rowLine: row.line, index: index, count: players.count),
                    team: team
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlayerNode: View {
    let player: RosterPlayer
    let position: String
    let team: Team?

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottomTrailing) {
                jerseyAvatar
                if let rating = playerRating(player) {
                    Text(rating)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(height: 16)
                        .background(ratingColor(rating))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .offset(x: 8, y: 4)
                }
            }

            Text(position)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)

            Text(playerName)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: 58)
        }
        .frame(width: 62)
    }

    private var jerseyAvatar: some View {
        JerseyShape()
            .fill(
                LinearGradient(
                    colors: jerseyColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(player.jersey ?? "")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 1, x: 0, y: 1)
            )
            .overlay(JerseyShape().stroke(Color.white.opacity(0.24), lineWidth: 1))
            .frame(width: 38, height: 40)
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
    }

    private var jerseyColors: [Color] {
        guard let team else {
            return [Color.white.opacity(0.22), Color.white.opacity(0.08)]
        }
        return [
            team.lineupPrimaryColor,
            team.lineupSecondaryColor.opacity(0.75),
            team.lineupPrimaryColor.opacity(0.78)
        ]
    }

    private var playerName: String {
        let name = player.athlete?.bestName ?? "Player"
        if let jersey = player.jersey, !jersey.isEmpty {
            return "\(jersey) \(name)"
        }
        return name
    }
}

struct BenchList: View {
    let group: RosterGroup

    private var bench: [RosterPlayer] {
        (group.roster ?? []).filter { $0.starter != true }
    }

    var body: some View {
        if !bench.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(group.team?.abbreviation ?? "Team")
                        .foregroundStyle(Color.pitchAccent)
                    Text("Bench")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.caption.weight(.black))

                ForEach(bench) { player in
                    HStack(spacing: 10) {
                        Text(player.jersey ?? "-")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.athlete?.bestName ?? "Player")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(positionLabel(for: player, rowLine: "bench", index: 0, count: 1))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if player.subbedIn == true {
                            Text("IN")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(Color.pitchAccent)
                        } else if player.subbedOut == true {
                            Text("OUT")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(9)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct PitchMarkings: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let line = Color.white.opacity(0.3)
            let boxWidth = min(width * 0.52, 168)
            let boxHeight = height * 0.075
            let sixWidth = boxWidth * 0.46
            let sixHeight = boxHeight * 0.52

            ZStack {
                Rectangle()
                    .fill(line)
                    .frame(height: 2)
                    .position(x: width / 2, y: height / 2)

                Circle()
                    .stroke(line, lineWidth: 2)
                    .frame(width: 128, height: 128)
                    .position(x: width / 2, y: height / 2)

                penaltyBox(width: boxWidth, height: boxHeight, sixWidth: sixWidth, sixHeight: sixHeight)
                    .stroke(line, lineWidth: 2)
                    .frame(width: boxWidth, height: boxHeight)
                    .position(x: width / 2, y: boxHeight / 2)

                penaltyBox(width: boxWidth, height: boxHeight, sixWidth: sixWidth, sixHeight: sixHeight)
                    .stroke(line, lineWidth: 2)
                    .frame(width: boxWidth, height: boxHeight)
                    .rotationEffect(.degrees(180))
                    .position(x: width / 2, y: height - boxHeight / 2)

                cornerArcs(width: width, height: height, radius: 14)
                    .stroke(line, lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }

    private func penaltyBox(width: CGFloat, height: CGFloat, sixWidth: CGFloat, sixHeight: CGFloat) -> Path {
        var path = Path()
        path.addRect(CGRect(x: 0, y: 0, width: width, height: height))
        path.addRect(CGRect(x: (width - sixWidth) / 2, y: 0, width: sixWidth, height: sixHeight))
        path.addArc(
            center: CGPoint(x: width / 2, y: height),
            radius: width * 0.25,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        return path
    }

    private func cornerArcs(width: CGFloat, height: CGFloat, radius: CGFloat) -> Path {
        var path = Path()
        let size = radius * 2
        path.addEllipse(in: CGRect(x: -radius, y: -radius, width: size, height: size))
        path.addEllipse(in: CGRect(x: width - radius, y: -radius, width: size, height: size))
        path.addEllipse(in: CGRect(x: -radius, y: height - radius, width: size, height: size))
        path.addEllipse(in: CGRect(x: width - radius, y: height - radius, width: size, height: size))
        return path
    }
}

struct JerseyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()

        path.move(to: CGPoint(x: width * 0.31, y: height * 0.05))
        path.addLine(to: CGPoint(x: width * 0.42, y: height * 0.00))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.58, y: height * 0.00),
            control: CGPoint(x: width * 0.50, y: height * 0.08)
        )
        path.addLine(to: CGPoint(x: width * 0.69, y: height * 0.05))
        path.addLine(to: CGPoint(x: width * 0.96, y: height * 0.25))
        path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.47))
        path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.42))
        path.addLine(to: CGPoint(x: width * 0.72, y: height * 0.95))
        path.addLine(to: CGPoint(x: width * 0.28, y: height * 0.95))
        path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.42))
        path.addLine(to: CGPoint(x: width * 0.18, y: height * 0.47))
        path.addLine(to: CGPoint(x: width * 0.04, y: height * 0.25))
        path.closeSubpath()

        return path
    }
}
