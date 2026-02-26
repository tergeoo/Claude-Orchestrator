import SwiftUI
import UIKit

// MARK: - ActivityFeedView

struct ActivityFeedView: View {
    @ObservedObject var session: TerminalSession
    @EnvironmentObject var relay: RelayWebSocket

    var body: some View {
        ZStack {
            if session.claudeLaunched {
                FeedView(session: session)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            } else {
                LaunchClaudeView(session: session)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: session.claudeLaunched)
    }
}

// MARK: - LaunchClaudeView

private struct LaunchClaudeView: View {
    @ObservedObject var session: TerminalSession
    @EnvironmentObject var relay: RelayWebSocket

    @State private var showFolderPicker = false
    @State private var pickedPath = "~"
    @State private var isDangerous = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 32)

                // Hero
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.07))
                            .frame(width: 112, height: 112)
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "sparkles")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(spacing: 6) {
                        Text("Start Claude")
                            .font(.system(size: 26, weight: .bold))
                        Text("Choose a project folder and launch a session")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)

                // Folder picker
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(icon: "folder.fill", title: "Working Directory")

                    Button { showFolderPicker = true } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.yellow.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.yellow)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pickedPath == "~" ? "Home Directory" : folderName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(pickedPath)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                // Mode selector
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(icon: "shield.fill", title: "Session Mode")

                    HStack(spacing: 10) {
                        ModeCard(
                            icon: "checkmark.shield.fill",
                            title: "Normal",
                            subtitle: "Confirms before risky actions",
                            color: .green,
                            isSelected: !isDangerous
                        ) { withAnimation(.easeInOut(duration: 0.18)) { isDangerous = false } }

                        ModeCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Dangerous",
                            subtitle: "Skips all confirmations",
                            color: .orange,
                            isSelected: isDangerous
                        ) { withAnimation(.easeInOut(duration: 0.18)) { isDangerous = true } }
                    }

                    if isDangerous {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(.top, 1)
                            Text("Claude can read, write and delete files without asking. Use only in trusted projects.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 24)

                // Launch button
                Button { launchClaude() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(isDangerous ? "Launch in Dangerous Mode" : "Launch Claude")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: isDangerous
                                ? [Color.orange, Color.orange.opacity(0.8)]
                                : [Color.accentColor, Color.accentColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(
                        color: (isDangerous ? Color.orange : Color.accentColor).opacity(0.35),
                        radius: 14, x: 0, y: 6
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.2), value: isDangerous)

                Spacer(minLength: 40)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showFolderPicker) {
            FileBrowserView(
                agentID: session.agent.id,
                agentName: session.agent.name
            ) { path, dangerous in
                pickedPath = path
                isDangerous = dangerous
                launchClaude()
            }
            .environmentObject(relay)
        }
    }

    private var folderName: String {
        URL(fileURLWithPath: pickedPath).lastPathComponent
    }

    private func launchClaude() {
        let cmd = isDangerous
            ? "cd \"\(pickedPath)\" && claude --dangerously-skip-permissions\n"
            : "cd \"\(pickedPath)\" && claude\n"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        relay.sendInput(sessionID: session.id, data: Data(cmd.utf8))
        withAnimation {
            session.claudeLaunched = true
        }
    }
}

// MARK: - FeedView (Claude is running)

private struct FeedView: View {
    @ObservedObject var session: TerminalSession
    @EnvironmentObject var relay: RelayWebSocket

    @State private var taskText = ""
    @FocusState private var isComposerFocused: Bool
    @State private var keyboardOverlap: CGFloat = 0
    @State private var viewMaxY: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Working banner
            if case .working(let n) = session.claudeState {
                ClaudeWorkingBanner(toolsUsed: n)
            }

            feedList
            Divider()
            composerBar.background(.bar)
            Color.clear.frame(height: keyboardOverlap)
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: FeedMaxYKey.self, value: geo.frame(in: .global).maxY)
            }
        )
        .onPreferenceChange(FeedMaxYKey.self) { viewMaxY = $0 }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { n in
            guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let dur = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: dur)) { keyboardOverlap = max(0, viewMaxY - frame.minY) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { n in
            let dur = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: dur)) { keyboardOverlap = 0 }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var feedList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(session.activityLog) { event in
                        ActivityEventRow(event: event).id(event.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .onChange(of: session.activityLog.count) { _, _ in
                if let last = session.activityLog.last {
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.bottom, 11)

                TextField("Send a task to Claude\u{2026}", text: $taskText, axis: .vertical)
                    .focused($isComposerFocused)
                    .font(.system(size: 15))
                    .lineLimit(1...6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button { sendTask() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AnyShapeStyle(Color(UIColor.tertiaryLabel))
                            : AnyShapeStyle(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .disabled(taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .animation(.easeInOut(duration: 0.15),
                       value: taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendTask() {
        let trimmed = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        session.logUserInput(trimmed)
        relay.sendInput(sessionID: session.id, data: Data((trimmed + "\n").utf8))
        taskText = ""
    }
}

// MARK: - ClaudeWorkingBanner

private struct ClaudeWorkingBanner: View {
    let toolsUsed: Int
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.orange)
                .frame(width: 7, height: 7)
                .scaleEffect(pulse ? 1.35 : 1.0)
                .opacity(pulse ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            Text(toolsUsed > 0
                 ? "Claude is working \u{00B7} \(toolsUsed) tool\(toolsUsed == 1 ? "" : "s") used"
                 : "Claude is working\u{2026}")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.09))
    }
}

// MARK: - SectionLabel

private struct SectionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 2)
    }
}

// MARK: - ModeCard

private struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .white : color)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? AnyShapeStyle(color.gradient)
                    : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.clear : color.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PreferenceKey

private struct FeedMaxYKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - ActivityEventRow

struct ActivityEventRow: View {
    let event: ActivityEvent

    var body: some View {
        switch event.kind {
        case .sessionStarted:
            sessionDivider(label: "Session started \u{00B7} \(event.timestamp.formatted(.dateTime.hour().minute()))")
        case .sessionEnded:
            sessionDivider(label: "Session ended")
        case .userInput(let text):
            userInputRow(text: text)
        case .claudeText(let text):
            claudeTextRow(text: text)
        case .toolCall(let name, let args):
            toolCallRow(name: name, args: args)
        }
    }

    private func sessionDivider(label: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5)
            Text(label).font(.caption).foregroundStyle(.tertiary).fixedSize()
            Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5)
        }
        .padding(.vertical, 8)
    }

    private func userInputRow(text: String) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            Spacer(minLength: 52)
            Text(text)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(event.timestamp.formatted(.dateTime.hour().minute()))
                .font(.caption2).foregroundStyle(.tertiary).padding(.bottom, 2)
        }
        .padding(.vertical, 2)
    }

    private func claudeTextRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                )
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 52)
        }
        .padding(.vertical, 2)
    }

    private func toolCallRow(name: String, args: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: toolIcon(for: name))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            if !args.isEmpty {
                Text(args.count > 55 ? String(args.prefix(55)) + "\u{2026}" : args)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(event.timestamp.formatted(.dateTime.hour().minute()))
                .font(.caption2).foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.vertical, 1)
    }

    private func toolIcon(for name: String) -> String {
        switch name {
        case "Bash":         return "terminal.fill"
        case "Read":         return "doc.text"
        case "Write":        return "square.and.pencil"
        case "Edit":         return "pencil.circle"
        case "Glob":         return "magnifyingglass"
        case "Grep":         return "doc.text.magnifyingglass"
        case "WebFetch":     return "globe"
        case "WebSearch":    return "globe.americas.fill"
        case "Task":         return "cpu"
        case "NotebookEdit": return "book.closed"
        default:             return "wrench.and.screwdriver"
        }
    }
}
