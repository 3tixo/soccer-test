import SwiftUI

struct ParlayView: View {
    let events: [ScoreEvent]
    let league: League
    @ObservedObject var store: ParlayStore

    @State private var title = ""
    @State private var stake = "10"
    @State private var legType: ParlayLegType = .homeWin
    @State private var line = "2.5"
    @State private var multiplier = "2.00"
    @State private var selectedEventId: String?
    @State private var draftLegs: [ParlayLeg] = []

    private var selectedEvent: ScoreEvent? {
        events.first { $0.id == selectedEventId } ?? events.first
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(kicker: "Tickets", title: "Parlays")
                    builder
                    existingTickets
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var builder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Ticket")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

            TextField("Ticket name", text: $title)
                .textFieldStyle(.plain)
                .fieldChrome()

            HStack(spacing: 10) {
                TextField("Stake", text: $stake)
                    .keyboardType(.decimalPad)
                    .fieldChrome()
                TextField("Leg multiplier", text: $multiplier)
                    .keyboardType(.decimalPad)
                    .fieldChrome()
            }

            Picker("Match", selection: selectedEventBinding) {
                ForEach(events) { event in
                    Text(matchName(event)).tag(event.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .padding(12)
            .background(Color.pitchSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("Leg type", selection: $legType) {
                ForEach(ParlayLegType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .padding(12)
            .background(Color.pitchSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if legType.needsLine {
                TextField("Goal line, for example 2.5", text: $line)
                    .keyboardType(.decimalPad)
                    .fieldChrome()
            }

            Button {
                addDraftLeg()
            } label: {
                Label("Add Leg", systemImage: "plus")
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.pitchSurface)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if !draftLegs.isEmpty {
                VStack(spacing: 8) {
                    ForEach(draftLegs) { leg in
                        parlayLegRow(leg, editable: false, ticketId: nil)
                    }
                }
            }

            Button {
                saveTicket()
            } label: {
                Text("Save Ticket")
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(canSave ? Color.pitchAccent : Color.white.opacity(0.10))
                    .foregroundStyle(canSave ? Color.pitchBackground : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .disabled(!canSave)
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.pitchCard)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var existingTickets: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(kicker: "Tracking", title: "Saved Tickets")

            if store.tickets.isEmpty {
                StateCard(title: "No tickets yet", detail: "Add a single pick or multiple legs, then update each leg as it hits or loses.")
            } else {
                ForEach(store.tickets) { ticket in
                    ticketCard(ticket)
                }
            }
        }
    }

    private func ticketCard(_ ticket: ParlayTicket) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("\(ticket.progressText) - \(currency(ticket.stake)) stake - \(currency(ticket.potentialPayout)) payout")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(ticket.status.rawValue.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(ticket.status == .lost ? .white : Color.pitchBackground)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(ticket.status == .lost ? Color.red.opacity(0.90) : Color.pitchAccent)
                    .clipShape(Capsule())
            }

            ForEach(ticket.legs) { leg in
                parlayLegRow(leg, editable: true, ticketId: ticket.id)
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        if await store.requestNotificationPermission() {
                            store.sendStatusNotification(for: ticket)
                        }
                    }
                } label: {
                    Label("Notify", systemImage: "bell")
                }

                Button {
                    Task {
                        await store.startLiveActivity(for: ticket)
                    }
                } label: {
                    Label("Live", systemImage: "bolt.circle")
                }

                Button(role: .destructive) {
                    store.delete(ticket)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .font(.caption.weight(.black))
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(Color.pitchSurface)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func parlayLegRow(_ leg: ParlayLeg, editable: Bool, ticketId: UUID?) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(leg.matchName)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(leg.market): \(leg.pick) - x\(leg.multiplier.formatted(.number.precision(.fractionLength(2))))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if editable, let ticketId {
                Picker("Status", selection: statusBinding(ticketId: ticketId, leg: leg)) {
                    ForEach(ParlayLegStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            } else {
                Text(leg.status.rawValue)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var selectedEventBinding: Binding<String> {
        Binding(
            get: { selectedEventId ?? events.first?.id ?? "" },
            set: { selectedEventId = $0 }
        )
    }

    private func statusBinding(ticketId: UUID, leg: ParlayLeg) -> Binding<ParlayLegStatus> {
        Binding(
            get: { leg.status },
            set: { store.updateLeg(ticketId: ticketId, legId: leg.id, status: $0) }
        )
    }

    private var canSave: Bool {
        !draftLegs.isEmpty && (Double(stake) ?? 0) > 0
    }

    private func addDraftLeg() {
        guard let event = selectedEvent else { return }
        let goalLine = Double(line)
        guard !legType.needsLine || goalLine != nil else { return }
        draftLegs.append(
            ParlayLeg(
                eventId: event.id,
                matchName: matchName(event),
                market: legType.marketTitle(event: event),
                pick: legType.pickTitle(event: event, line: goalLine),
                type: legType,
                line: goalLine,
                multiplier: Double(multiplier) ?? 1,
                status: .pending
            )
        )
    }

    private func saveTicket() {
        guard canSave else { return }
        store.add(
            ParlayTicket(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultTicketTitle : title,
                stake: Double(stake) ?? 0,
                legs: draftLegs
            )
        )
        title = ""
        draftLegs = []
    }

    private var defaultTicketTitle: String {
        draftLegs.count <= 1 ? "Single Ticket" : "\(draftLegs.count)-Leg Parlay"
    }

    private func matchName(_ event: ScoreEvent) -> String {
        let teams = event.matchTeams
        return "\(teams.home?.team?.bestName ?? "Home") vs \(teams.away?.team?.bestName ?? "Away")"
    }
}

private extension View {
    func fieldChrome() -> some View {
        self
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.pitchSurface)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
