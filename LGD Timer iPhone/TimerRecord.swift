import Foundation
import SwiftData

@Model
final class TimerRecord {
    var startedAt: Date
    var totalDuration: Int
    var speakerLimit: Int
    var speakerDurations: [Int]
    var thinkingDuration: Int?
    var discussionDuration: Int?

    init(
        startedAt: Date,
        totalDuration: Int,
        speakerLimit: Int,
        speakerDurations: [Int],
        thinkingDuration: Int? = nil,
        discussionDuration: Int? = nil
    ) {
        self.startedAt = startedAt
        self.totalDuration = totalDuration
        self.speakerLimit = speakerLimit
        self.speakerDurations = speakerDurations
        self.thinkingDuration = thinkingDuration
        self.discussionDuration = discussionDuration
    }

    var speakerCount: Int {
        speakerDurations.count
    }

    var resolvedThinkingDuration: Int {
        thinkingDuration ?? max(0, totalDuration - speakerDurations.reduce(0, +))
    }

    var resolvedDiscussionDuration: Int {
        discussionDuration ?? 0
    }
}
