import SwiftUI
import WatchKit

struct ContentView: View {
    @AppStorage("customDurations") private var storedCustomDurations = ""
    @AppStorage("discussionHistory") private var storedHistory = ""
    @State private var activeDuration: Int?
    @State private var showingAddDuration = false

    private let presets = [60, 120, 180]

    private var customDurations: [Int] {
        storedCustomDurations.split(separator: ",")
            .compactMap { Int($0) }
            .filter { $0 > 0 }
            .sorted()
    }

    var body: some View {
        Group {
            if let activeDuration {
                DiscussionTimerView(
                    limit: activeDuration,
                    onSave: saveRecord,
                    onEnd: { self.activeDuration = nil }
                )
            } else {
                durationPicker
            }
        }
        .animation(.snappy, value: activeDuration)
        .sheet(isPresented: $showingAddDuration) {
            AddDurationView { seconds in addCustomDuration(seconds) }
        }
    }

    private var durationPicker: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(presets, id: \.self) { durationButton(seconds: $0) }
                } header: {
                    Text("个人发言时限")
                } footer: {
                    Text("进入后，整场计时会从 00:00 运行。")
                }

                if !customDurations.isEmpty {
                    Section("自定义") {
                        ForEach(customDurations, id: \.self) { seconds in
                            durationButton(seconds: seconds)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        deleteCustomDuration(seconds)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                Section {
                    Button {
                        showingAddDuration = true
                    } label: {
                        Label("添加自定义时长", systemImage: "plus.circle.fill")
                    }
                    .tint(.orange)
                }

                if !history.isEmpty {
                    Section("历史记录") {
                        ForEach(history) { record in
                            NavigationLink {
                                HistoryDetailView(record: record)
                            } label: {
                                HistoryRow(record: record)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteRecord(record.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("讨论计时")
        }
    }

    private func durationButton(seconds: Int) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            activeDuration = seconds
        } label: {
            HStack {
                Image(systemName: "timer").foregroundStyle(.orange)
                Text(durationLabel(seconds))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func addCustomDuration(_ seconds: Int) {
        var values = customDurations
        guard !presets.contains(seconds), !values.contains(seconds) else { return }
        values.append(seconds)
        storedCustomDurations = values.sorted().map(String.init).joined(separator: ",")
    }

    private func deleteCustomDuration(_ seconds: Int) {
        storedCustomDurations = customDurations
            .filter { $0 != seconds }
            .map(String.init)
            .joined(separator: ",")
    }

    private var history: [DiscussionRecord] {
        HistoryStorage.decode(storedHistory)
    }

    private func saveRecord(_ record: DiscussionRecord) {
        var records = history
        records.insert(record, at: 0)
        storedHistory = HistoryStorage.encode(Array(records.prefix(50)))
    }

    private func deleteRecord(_ id: UUID) {
        storedHistory = HistoryStorage.encode(history.filter { $0.id != id })
    }
}

private struct AddDurationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 1
    @State private var seconds = 30
    let onSave: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    Text(durationLabel(totalSeconds))
                        .font(.headline.monospacedDigit().bold())
                        .foregroundStyle(.orange)

                    CompactNumberStepper(value: $minutes, range: 0...30, unit: "分")
                    CompactNumberStepper(value: $seconds, range: 0...59, unit: "秒")

                    Button("保存") {
                        onSave(totalSeconds)
                        WKInterfaceDevice.current().play(.success)
                        dismiss()
                    }
                    .disabled(totalSeconds == 0)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal)
            .navigationTitle("自定义")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var totalSeconds: Int { minutes * 60 + seconds }
}

private struct CompactNumberStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            compactButton(systemName: "minus") {
                value = max(range.lowerBound, value - 1)
            }
            .disabled(value == range.lowerBound)

            Text("\(value) \(unit)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 58)

            compactButton(systemName: "plus") {
                value = min(range.upperBound, value + 1)
            }
            .disabled(value == range.upperBound)
        }
    }

    private func compactButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.bold))
                .frame(width: 42, height: 42)
                .background(.gray.opacity(0.22), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct DiscussionTimerView: View {
    let limit: Int
    let onSave: (DiscussionRecord) -> Void
    let onEnd: () -> Void

    @State private var sessionStart = Date()
    @State private var firstSpeakerStart: Date?
    @State private var speakerStart: Date?
    @State private var discussionStart: Date?
    @State private var speakerNumber = 0
    @State private var completedSpeakers: [Int] = []
    @State private var didAlert = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let totalSeconds = max(0, Int(context.date.timeIntervalSince(sessionStart)))
            let speakerSeconds = speakerStart.map {
                max(0, Int(context.date.timeIntervalSince($0)))
            }
            let discussionSeconds = discussionStart.map {
                max(0, Int(context.date.timeIntervalSince($0)))
            }

            ScrollView {
                VStack(spacing: 7) {
                    totalClock(seconds: totalSeconds)
                    Divider()
                    if discussionStart == nil {
                        speakerClock(seconds: speakerSeconds)
                    } else {
                        discussionClock(seconds: discussionSeconds ?? 0)
                    }

                    if discussionStart == nil {
                        Button {
                            startNextSpeaker()
                        } label: {
                            Label(speakerStart == nil ? "开始首位发言" : "下一位发言",
                                  systemImage: "forward.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button {
                            startDiscussion()
                        } label: {
                            Label("开始讨论", systemImage: "person.3.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(speakerStart == nil)
                    }

                    Button(role: .destructive) {
                        finishDiscussion()
                    } label: {
                        Label("结束并保存", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: speakerSeconds) { _, newValue in
                guard let newValue, newValue >= limit, !didAlert else { return }
                didAlert = true
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    private func totalClock(seconds: Int) -> some View {
        VStack(spacing: 0) {
            Label("整场时间", systemImage: "person.3.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(clockString(seconds))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func speakerClock(seconds: Int?) -> some View {
        let isOvertime = (seconds ?? 0) >= limit

        return VStack(spacing: 1) {
            Text(speakerNumber == 0 ? "等待发言" : "第 \(speakerNumber) 位")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(seconds.map(clockString) ?? "--:--")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isOvertime ? .red : .primary)
                .contentTransition(.numericText())
            Text(isOvertime ? "已超时 \(clockString((seconds ?? limit) - limit))" : "时限 \(durationLabel(limit))")
                .font(.caption2.weight(.medium))
                .foregroundStyle(isOvertime ? .red : .orange)
        }
        .animation(.easeInOut(duration: 0.2), value: isOvertime)
    }

    private func startNextSpeaker() {
        let now = Date()
        if let speakerStart {
            completedSpeakers.append(max(0, Int(now.timeIntervalSince(speakerStart))))
        } else {
            firstSpeakerStart = now
        }
        speakerNumber += 1
        speakerStart = now
        didAlert = false
        WKInterfaceDevice.current().play(.start)
    }

    private func startDiscussion() {
        let now = Date()
        if let speakerStart {
            completedSpeakers.append(max(0, Int(now.timeIntervalSince(speakerStart))))
        }
        speakerStart = nil
        discussionStart = now
        didAlert = false
        WKInterfaceDevice.current().play(.start)
    }

    private func finishDiscussion() {
        let endDate = Date()
        var durations = completedSpeakers
        if let speakerStart {
            durations.append(max(0, Int(endDate.timeIntervalSince(speakerStart))))
        }

        if !durations.isEmpty {
            let thinkingDuration = firstSpeakerStart.map {
                max(0, Int($0.timeIntervalSince(sessionStart)))
            } ?? 0
            let discussionDuration = discussionStart.map {
                max(0, Int(endDate.timeIntervalSince($0)))
            } ?? 0
            let totalDuration = thinkingDuration + durations.reduce(0, +) + discussionDuration

            onSave(DiscussionRecord(
                date: endDate,
                totalDuration: totalDuration,
                speakerLimit: limit,
                speakerDurations: durations,
                thinkingDuration: thinkingDuration,
                discussionDuration: discussionDuration
            ))
        }
        WKInterfaceDevice.current().play(.success)
        onEnd()
    }

    private func discussionClock(seconds: Int) -> some View {
        VStack(spacing: 1) {
            Text("集中讨论")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(clockString(seconds))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
            Text("讨论进行中")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
        }
    }

}

private struct DiscussionRecord: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let totalDuration: Int
    let speakerLimit: Int
    let speakerDurations: [Int]
    let thinkingDuration: Int?
    let discussionDuration: Int?

    init(
        id: UUID = UUID(),
        date: Date,
        totalDuration: Int,
        speakerLimit: Int,
        speakerDurations: [Int],
        thinkingDuration: Int? = nil,
        discussionDuration: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.totalDuration = totalDuration
        self.speakerLimit = speakerLimit
        self.speakerDurations = speakerDurations
        self.thinkingDuration = thinkingDuration
        self.discussionDuration = discussionDuration
    }

    var resolvedThinkingDuration: Int {
        thinkingDuration ?? max(0, totalDuration - speakerDurations.reduce(0, +))
    }

    var resolvedDiscussionDuration: Int {
        discussionDuration ?? 0
    }
}

private enum HistoryStorage {
    static func decode(_ value: String) -> [DiscussionRecord] {
        guard let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([DiscussionRecord].self, from: data)) ?? []
    }

    static func encode(_ records: [DiscussionRecord]) -> String {
        guard let data = try? JSONEncoder().encode(records) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private struct HistoryRow: View {
    let record: DiscussionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.date.formatted(date: .numeric, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Label(clockString(record.totalDuration), systemImage: "clock")
                Spacer()
                Label("\(record.speakerDurations.count) 人", systemImage: "person.2")
            }
            .font(.caption.weight(.semibold))
        }
    }
}

private struct HistoryDetailView: View {
    let record: DiscussionRecord

    var body: some View {
        List {
            Section {
                LabeledContent("整场时间", value: clockString(record.totalDuration))
                LabeledContent("个人时限", value: durationLabel(record.speakerLimit))
                LabeledContent("发言人数", value: "\(record.speakerDurations.count)")
            }

            Section("发言记录") {
                LabeledContent("思考时间", value: clockString(record.resolvedThinkingDuration))

                ForEach(Array(record.speakerDurations.enumerated()), id: \.offset) { index, duration in
                    HStack {
                        Text("第 \(index + 1) 位")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(clockString(duration)).monospacedDigit()
                            if duration > record.speakerLimit {
                                Text("超时 \(clockString(duration - record.speakerLimit))")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                LabeledContent("讨论时间", value: clockString(record.resolvedDiscussionDuration))
            }
        }
        .navigationTitle("讨论记录")
    }
}

private func clockString(_ totalSeconds: Int) -> String {
    let safeSeconds = max(0, totalSeconds)
    return String(format: "%02d:%02d", safeSeconds / 60, safeSeconds % 60)
}

private func durationLabel(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds) 秒" }
    if seconds.isMultiple(of: 60) { return "\(seconds / 60) 分钟" }
    return "\(seconds / 60) 分 \(seconds % 60) 秒"
}

#Preview {
    ContentView()
}
