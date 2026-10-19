import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    var body: some View {
        TabView {
            TimerHomeView()
                .tabItem {
                    Label("计时", systemImage: "timer")
                }

            HistoryView()
                .tabItem {
                    Label("记录", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(.orange)
    }
}

private struct TimerHomeView: View {
    @AppStorage("iphoneCustomDurations") private var storedCustomDurations = ""
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
        NavigationStack {
            Group {
                if let activeDuration {
                    DiscussionTimerView(limit: activeDuration) {
                        self.activeDuration = nil
                    }
                } else {
                    durationPicker
                }
            }
            .navigationTitle(activeDuration == nil ? "讨论计时" : "进行中")
            .navigationBarTitleDisplayMode(.large)
            .animation(.snappy, value: activeDuration)
            .sheet(isPresented: $showingAddDuration) {
                AddDurationView { seconds in
                    addCustomDuration(seconds)
                }
            }
        }
    }

    private var durationPicker: some View {
        List {
            Section {
                ForEach(presets, id: \.self) { seconds in
                    durationButton(seconds: seconds)
                }
            } header: {
                Text("个人发言时限")
            } footer: {
                Text("选择时限后开始整场计时。每位发言者会单独计时。")
            }

            if !customDurations.isEmpty {
                Section("自定义") {
                    ForEach(customDurations, id: \.self) { seconds in
                        durationButton(seconds: seconds)
                            .swipeActions {
                                Button("删除", systemImage: "trash", role: .destructive) {
                                    deleteCustomDuration(seconds)
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
            }
        }
    }

    private func durationButton(seconds: Int) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            activeDuration = seconds
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 28)
                Text(durationLabel(seconds))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
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
}

private struct AddDurationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 4
    @State private var seconds = 0
    let onSave: (Int) -> Void

    private var totalSeconds: Int {
        minutes * 60 + seconds
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Picker("分钟", selection: $minutes) {
                            ForEach(0...60, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .accessibilityLabel("分钟")

                        Text("分")
                            .foregroundStyle(.secondary)

                        Picker("秒钟", selection: $seconds) {
                            ForEach(0...59, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .accessibilityLabel("秒钟")

                        Text("秒")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 150)
                } header: {
                    Text("发言时限")
                } footer: {
                    Text("当前时限：\(durationLabel(totalSeconds))")
                }
            }
            .navigationTitle("自定义时长")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(totalSeconds)
                        dismiss()
                    }
                    .disabled(totalSeconds == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct DiscussionTimerView: View {
    @Environment(\.modelContext) private var modelContext

    let limit: Int
    let onEnd: () -> Void

    @State private var sessionStart = Date()
    @State private var firstSpeakerStart: Date?
    @State private var speakerStart: Date?
    @State private var discussionStart: Date?
    @State private var completedSpeakerDurations: [Int] = []
    @State private var didAlert = false
    @State private var showingEndConfirmation = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let totalSeconds = elapsed(from: sessionStart, to: context.date)
            let speakerSeconds = speakerStart.map { elapsed(from: $0, to: context.date) }
            let discussionSeconds = discussionStart.map { elapsed(from: $0, to: context.date) }

            ScrollView {
                VStack(spacing: 28) {
                    totalClock(seconds: totalSeconds)
                    if discussionStart == nil {
                        speakerClock(seconds: speakerSeconds)
                    } else {
                        discussionClock(seconds: discussionSeconds ?? 0)
                    }

                    VStack(spacing: 12) {
                        if discussionStart == nil {
                            Button {
                                startNextSpeaker(at: context.date)
                            } label: {
                                Label(
                                    speakerStart == nil ? "开始首位发言" : "下一位发言",
                                    systemImage: "forward.fill"
                                )
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 34)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)

                            Button {
                                startDiscussion(at: context.date)
                            } label: {
                                Label("开始讨论", systemImage: "person.3.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 34)
                            }
                            .buttonStyle(.bordered)
                            .disabled(speakerStart == nil)
                        }

                        Button(role: .destructive) {
                            showingEndConfirmation = true
                        } label: {
                            Label("结束并保存", systemImage: "stop.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .onChange(of: speakerSeconds) { _, newValue in
                guard let newValue, newValue >= limit, !didAlert else { return }
                didAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            .alert("结束本次讨论？", isPresented: $showingEndConfirmation) {
                Button("取消", role: .cancel) {}
                Button("结束并保存", role: .destructive) {
                    finishSession(at: Date())
                }
            } message: {
                Text("思考时间、每位发言者的用时和集中讨论时间将保存到记录中。")
            }
        }
    }

    private func totalClock(seconds: Int) -> some View {
        VStack(spacing: 6) {
            Label("整场时间", systemImage: "person.3.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(clockString(seconds))
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func speakerClock(seconds: Int?) -> some View {
        let isOvertime = (seconds ?? 0) >= limit
        let speakerNumber = completedSpeakerDurations.count + (speakerStart == nil ? 0 : 1)

        return VStack(spacing: 10) {
            Text(speakerNumber == 0 ? "等待发言" : "第 \(speakerNumber) 位发言者")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(seconds.map(clockString) ?? "--:--")
                .font(.system(size: 78, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .monospacedDigit()
                .foregroundStyle(isOvertime ? .red : .primary)
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }

            Text(isOvertime ? "已超时 \(clockString((seconds ?? limit) - limit))" : "时限 \(durationLabel(limit))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOvertime ? .red : .orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func startNextSpeaker(at date: Date) {
        if let speakerStart {
            completedSpeakerDurations.append(elapsed(from: speakerStart, to: date))
        } else {
            firstSpeakerStart = date
        }
        speakerStart = date
        didAlert = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func startDiscussion(at date: Date) {
        if let speakerStart {
            completedSpeakerDurations.append(elapsed(from: speakerStart, to: date))
        }
        speakerStart = nil
        discussionStart = date
        didAlert = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func finishSession(at date: Date) {
        var durations = completedSpeakerDurations
        if let speakerStart {
            durations.append(elapsed(from: speakerStart, to: date))
        }

        guard !durations.isEmpty else {
            onEnd()
            return
        }

        let thinkingDuration = firstSpeakerStart.map {
            elapsed(from: sessionStart, to: $0)
        } ?? 0
        let discussionDuration = discussionStart.map {
            elapsed(from: $0, to: date)
        } ?? 0
        let totalDuration = thinkingDuration + durations.reduce(0, +) + discussionDuration

        let record = TimerRecord(
            startedAt: sessionStart,
            totalDuration: totalDuration,
            speakerLimit: limit,
            speakerDurations: durations,
            thinkingDuration: thinkingDuration,
            discussionDuration: discussionDuration
        )
        modelContext.insert(record)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onEnd()
    }

    private func discussionClock(seconds: Int) -> some View {
        VStack(spacing: 10) {
            Text("集中讨论")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(clockString(seconds))
                .font(.system(size: 78, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .monospacedDigit()
                .foregroundStyle(.orange)
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }

            Text("讨论进行中")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerRecord.startedAt, order: .reverse) private var records: [TimerRecord]
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "暂无计时记录",
                        systemImage: "clock.badge.questionmark",
                        description: Text("结束一次讨论后，记录会出现在这里。")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            NavigationLink {
                                RecordDetailView(record: record)
                            } label: {
                                RecordRow(record: record)
                            }
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("计时记录")
            .toolbar {
                if !records.isEmpty {
                    Button(editMode == .active ? "完成" : "编辑") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}

private struct RecordRow: View {
    let record: TimerRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(chineseDateTime(record.startedAt, date: .abbreviated))
                .font(.headline)
            HStack(spacing: 16) {
                Label(clockString(record.totalDuration), systemImage: "clock")
                Label("\(record.speakerCount) 人", systemImage: "person.2")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct RecordDetailView: View {
    let record: TimerRecord

    var body: some View {
        List {
            Section("概览") {
                LabeledContent("开始时间", value: chineseDateTime(record.startedAt, date: .long))
                LabeledContent("整场时长", value: clockString(record.totalDuration))
                LabeledContent("个人时限", value: durationLabel(record.speakerLimit))
                LabeledContent("发言人数", value: "\(record.speakerCount)")
            }

            if !record.speakerDurations.isEmpty {
                Section("发言记录") {
                    LabeledContent("思考时间", value: clockString(record.resolvedThinkingDuration))

                    ForEach(Array(record.speakerDurations.enumerated()), id: \.offset) { index, duration in
                        HStack {
                            Text("第 \(index + 1) 位")
                            Spacer()
                            Text(clockString(duration))
                                .monospacedDigit()
                                .foregroundStyle(duration > record.speakerLimit ? .red : .secondary)
                        }
                    }

                    LabeledContent("讨论时间", value: clockString(record.resolvedDiscussionDuration))
                }
            }
        }
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func elapsed(from start: Date, to end: Date) -> Int {
    max(0, Int(end.timeIntervalSince(start)))
}

private func clockString(_ totalSeconds: Int) -> String {
    let safeSeconds = max(0, totalSeconds)
    let hours = safeSeconds / 3600
    let minutes = (safeSeconds % 3600) / 60
    let seconds = safeSeconds % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

private func durationLabel(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60

    if remainingSeconds == 0 {
        return "\(minutes) 分钟"
    }
    if minutes == 0 {
        return "\(remainingSeconds) 秒"
    }
    return "\(minutes) 分钟 \(remainingSeconds) 秒"
}

private func chineseDateTime(_ value: Date, date: Date.FormatStyle.DateStyle) -> String {
    value.formatted(
        Date.FormatStyle(
            date: date,
            time: .shortened,
            locale: Locale(identifier: "zh_CN")
        )
    )
}

#Preview {
    RootView()
        .modelContainer(for: TimerRecord.self, inMemory: true)
}
