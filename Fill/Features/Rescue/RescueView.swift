import SwiftUI
import SwiftData

// SPEC §7.8 — Rescue card: white card, fill greyed out behind.
// OOR: Extend / Restart / Scrap. Broken: Restart / Switch to flex / Scrap.
// Scrap needs two taps.
public struct RescueView: View {
    var challenge: Challenge
    var snapshot: Snapshot
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @State private var confirmScrap = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(snapshot.outOfReach ? Copy.rescueOOR : "Streak broken")
                .font(.system(size: 22, weight: .heavy))
            Text(reason()).font(.system(size: 15, weight: .medium)).foregroundStyle(FillColor.text2)
            if snapshot.outOfReach, let e = snapshot.endDate {
                let newEnd = e.adding(days: snapshot.extendBy)
                Button(Copy.extend(days: snapshot.extendBy, date: Format.date(newEnd))) { extend() }
                    .primaryBtn(color: challenge.colorToken)
            }
            Button("Restart from today") { restart() }.secondaryBtn()
            if snapshot.streakBroken {
                Button("Keep my \(snapshot.wins) days · switch to \(challenge.x) of \(challenge.x + 5) days") { switchToFlex() }
                    .secondaryBtn()
            }
            Button(confirmScrap ? "Tap again to scrap" : "Scrap challenge") { scrap() }
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(FillColor.danger)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .accessibilityLabel(confirmScrap ? "Tap again to scrap" : "Scrap challenge")
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.35), radius: 40, y: 18)
        .padding(.horizontal, 14).padding(.bottom, 100)
    }
    private func reason() -> String {
        if snapshot.outOfReach {
            return "You need \(snapshot.need) more wins, but only \(snapshot.daysLeft) days are left."
        }
        return "You missed day \(snapshot.streakBrokenOnDay ?? 0). Your streak is back to 0 unless you switch."
    }
    private func record() -> ChallengeRecord? {
        let id = challenge.id
        return (try? context.fetch(FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.id == id })))?.first
    }
    private func extend() {
        if let r = record() {
            r.y += snapshot.extendBy; r.outOfReachNotifiedAt = nil
            try? context.save()
            app.showToast("Extended by \(snapshot.extendBy) day\(snapshot.extendBy == 1 ? "" : "s").")
        }
    }
    private func restart() {
        if let r = record() {
            r.startKey = DayKey.from(date: Date(), calendar: .current).key
            r.restartCount += 1; r.claimedAt = nil; r.closedAt = nil; r.outOfReachNotifiedAt = nil
            try? context.save()
            app.showToast("Restarted from today.")
        }
    }
    private func switchToFlex() {
        if let r = record() {
            r.typeRaw = "flex"; r.y = challenge.x + 5
            try? context.save()
            app.showToast("Switched to Flexible.")
        }
    }
    private func scrap() {
        if !confirmScrap { confirmScrap = true; return }
        if let r = record() {
            r.archivedAt = Date()
            try? context.save()
            app.showToast("Challenge scrapped.")
        }
    }
}

private extension View {
    func primaryBtn(color: String) -> some View {
        self.font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(FillColor.color(for: color), in: RoundedRectangle(cornerRadius: 28))
    }
    func secondaryBtn() -> some View {
        self.font(.system(size: 16, weight: .semibold)).foregroundStyle(FillColor.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(FillColor.chipBg, in: RoundedRectangle(cornerRadius: 28))
    }
}
