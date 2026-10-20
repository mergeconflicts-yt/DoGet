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
            Text(snapshot.outOfReach ? Copy.rescueOOR : Copy.rescueBroken)
                .font(FillFont.scaled(22, weight: .heavy))
            Text(reason()).font(FillFont.scaled(15, weight: .medium)).foregroundStyle(FillColor.text2)
            if snapshot.outOfReach, let e = snapshot.endDate {
                let newEnd = e.adding(days: snapshot.extendBy)
                Button(Copy.extend(days: snapshot.extendBy, date: Format.date(newEnd))) { extend() }
                    .primaryBtn(color: challenge.colorToken)
            }
            Button(Copy.restartFromToday) { restart() }.secondaryBtn()
            if snapshot.streakBroken {
                Button(Copy.switchToFlex(wins: snapshot.wins, x: challenge.x)) { switchToFlex() }
                    .secondaryBtn()
            }
            Button(confirmScrap ? Copy.tapAgainToScrap : Copy.scrapChallenge) { scrap() }
                .font(FillFont.scaled(15, weight: .semibold)).foregroundStyle(FillColor.danger)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .accessibilityLabel(confirmScrap ? Copy.tapAgainToScrap : Copy.scrapChallenge)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: FillColor.shadow.opacity(0.35), radius: 40, y: 18)
        .padding(.horizontal, 14).padding(.bottom, 100)
        // R03: a stray tap must not leave the scrap confirmation armed.
        .task(id: confirmScrap) {
            guard confirmScrap else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { confirmScrap = false }
        }
    }
    private func reason() -> String {
        if snapshot.outOfReach {
            return Copy.rescueReasonOOR(need: snapshot.need, daysLeft: snapshot.daysLeft)
        }
        return Copy.rescueReasonStreak(day: snapshot.streakBrokenOnDay ?? 0)
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
            app.dataVersion += 1
            let end = snapshot.endDate?.adding(days: snapshot.extendBy)
            app.showToast(Copy.toastExtended(days: snapshot.extendBy,
                                             date: end.map(Format.date) ?? ""))
        }
    }
    private func restart() {
        if let r = record() {
            r.startKey = DayKey.from(date: Date(), calendar: .current).key
            r.restartCount += 1; r.claimedAt = nil; r.closedAt = nil; r.outOfReachNotifiedAt = nil
            try? context.save()
            app.dataVersion += 1
            app.showToast(Copy.toastRestarted)
        }
    }
    private func switchToFlex() {
        if let r = record() {
            let switched = Derive.switchedToFlex(challenge)
            r.typeRaw = switched.type.rawValue
            r.x = switched.x; r.y = switched.y
            try? context.save()
            app.dataVersion += 1
            app.showToast(Copy.toastSwitched(x: switched.x, y: switched.y))
        }
    }
    private func scrap() {
        if !confirmScrap { confirmScrap = true; return }
        if let r = record() {
            r.archivedAt = Date()
            try? context.save()
            app.dataVersion += 1
            app.showToast(Copy.toastScrapped)
        }
    }
}

private extension View {
    func primaryBtn(color: String) -> some View {
        self.font(FillFont.scaled(16, weight: .bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(FillColor.color(for: color), in: RoundedRectangle(cornerRadius: 28))
    }
    func secondaryBtn() -> some View {
        self.font(FillFont.scaled(16, weight: .semibold)).foregroundStyle(FillColor.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(FillColor.chipBg, in: RoundedRectangle(cornerRadius: 28))
    }
}
