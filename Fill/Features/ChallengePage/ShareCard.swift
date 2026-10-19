import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// ShareLink item: the rendered page as PNG data.
public struct ShareImage: Transferable {
    public var image: UIImage
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.image.pngData() ?? Data()
        }
    }
}

@MainActor
public enum ShareContent {
    /// iPhone 16 logical size — the exact challenge page, rendered offscreen.
    public static let pageSize = CGSize(width: 393, height: 852)

    /// Renders the real challenge page (not a redesign). Nil only if
    /// rendering fails. Body evaluation touches no store or actions, so a
    /// fresh AppState is enough for the environment.
    public static func renderImage(challenge: Challenge, snapshot: Snapshot,
                                   dayStates: [ChallengePageView.DayState],
                                   manualMode: Bool) -> UIImage? {
        let page = ChallengePageView(challenge: challenge, snapshot: snapshot,
                                     dayStates: dayStates, manualMode: manualMode,
                                     shareEnabled: false)
            .environment(AppState())
            .frame(width: pageSize.width, height: pageSize.height)
        let renderer = ImageRenderer(content: page)
        renderer.scale = 2
        return renderer.uiImage
    }
}
