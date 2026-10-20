import Foundation
import Observation

// SwiftUI-facing wrapper around the pure CreateLogic. Keeping @Observable
// here (not in Domain) is what lets Fill/Domain stay Foundation-only.
@Observable @MainActor
public final class CreateModel {
    public var logic = CreateLogic()

    public init() {}

    public var draft: Derive.Draft {
        get { logic.draft }
        set { logic.draft = newValue }
    }
    public var filled: Set<Int> {
        get { logic.filled }
        set { logic.filled = newValue }
    }
    public var openPanel: Int? {
        get { logic.openPanel }
        set { logic.openPanel = newValue }
    }
    public var hint: String? {
        get { logic.hint }
        set { logic.hint = newValue }
    }
    public var shakeBlank: Int? {
        get { logic.shakeBlank }
        set { logic.shakeBlank = newValue }
    }
    public var name: String {
        get { logic.name }
        set { logic.name = newValue; logic.nameEdited = true }
    }
    public var colorToken: String {
        get { logic.colorToken }
        set { logic.colorToken = newValue }
    }
    public var target: Double {
        get { logic.target }
        set { logic.target = newValue }
    }
    public var metric: Metric {
        get { logic.metric }
        set { logic.metric = newValue }
    }
    public var noWatch: Bool {
        get { logic.noWatch }
        set { logic.noWatch = newValue }
    }
    public var factsEnds: String { logic.factsEnds }
    public var factsMisses: String { logic.factsMisses }
    public var factsMax: String { logic.factsMax }
    public var buttonText: String { logic.buttonText }
    public var valid: Bool { logic.valid }
    public var problem: String? { logic.problem }
    public var autoName: String { logic.autoName }
    public var allowedPayouts: [MoneyPayout] { logic.allowedPayouts }

    public func tapBlank(_ i: Int) {
        logic.tapBlank(i)
        guard let shake = logic.shakeBlank else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            if logic.shakeBlank == shake { logic.shakeBlank = nil }
        }
    }

    public func done(_ i: Int) {
        logic.done(i)
        guard let next = logic.nextUnfilled else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.38))
            if logic.openPanel == nil { logic.openPanel = next }
        }
    }

    public func pickType(_ t: ChallengeType) { logic.pickType(t) }
    public func refreshFacts() { logic.refreshFacts() }
    public func buildReward() -> Reward { logic.buildReward() }
    public func blankName(_ i: Int) -> String { logic.blankName(i) }

    /// Typing the challenge name stops the item name from renaming it.
    public func setName(_ value: String) {
        logic.name = value
        logic.nameEdited = true
    }

    /// Item name edits only become the challenge name until the person types
    /// their own name; after that the two stay independent.
    public func setItemName(_ value: String) {
        logic.draft.itemName = value
        if !logic.nameEdited { logic.name = value }
        logic.refreshFacts()
    }
}
