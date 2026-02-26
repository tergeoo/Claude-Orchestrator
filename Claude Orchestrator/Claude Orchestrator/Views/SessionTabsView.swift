import SwiftUI

// MARK: - AppTab

enum AppTab: String, CaseIterable {
    case terminal = "Terminal"
    case activity = "Activity"
    case files    = "Files"
}

// MARK: - SessionTabsView

struct SessionTabsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var relay: RelayWebSocket
    @EnvironmentObject var authService: AuthService

    @State private var selectedSessionID: String?
    @State private var activeTab: AppTab = .terminal
    @State private var showMachineSelector = false
    @State private var showSettings = false
    @State private var showAddAgent = false

    var activeSession: TerminalSession? {
        sessionManager.sessions.first(where: { $0.id == selectedSessionID })
            ?? sessionManager.sessions.first
    }

    var body: some View {
        Group {
            if sessionManager.sessions.isEmpty {
                AgentListView()
            } else {
                mainView
            }
        }
    }

    // MARK: - Main layout

    private var mainView: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            reconnectingBanner
            TabView(selection: $activeTab) {
                terminalTab
                    .tag(AppTab.terminal)
                    .tabItem { Label("Terminal", systemImage: "terminal.fill") }

                activityTab
                    .tag(AppTab.activity)
                    .tabItem { Label("Activity", systemImage: "list.bullet.clipboard.fill") }

                filesTab
                    .tag(AppTab.files)
                    .tabItem { Label("Files", systemImage: "folder.fill") }
            }
        }
        .sheet(isPresented: $showMachineSelector) {
            machineSelectorSheet
                .environmentObject(relay)
                .environmentObject(sessionManager)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authService)
                .environmentObject(relay)
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showAddAgent) {
            AgentListView()
                .environmentObject(relay)
                .environmentObject(sessionManager)
                .environmentObject(authService)
        }
        .onChange(of: sessionManager.sessions) { _, sessions in
            if let last = sessions.last,
               selectedSessionID == nil || !sessions.contains(where: { $0.id == selectedSessionID }) {
                selectedSessionID = last.id
            }
        }
    }

    // MARK: - Top bar (44pt)

    private var topBar: some View {
        HStack(spacing: 12) {
            // Machine selector button
            Button {
                showMachineSelector = true
            } label: {
                HStack(spacing: 5) {
                    Text(machineName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Connection status
            HStack(spacing: 5) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                Text(connectionLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Settings
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .background(.bar)
    }

    private var machineName: String {
        guard let session = activeSession else { return "No Machine" }
        return session.agent.name.components(separatedBy: ".").first ?? session.agent.name
    }

    private var connectionColor: Color {
        switch relay.connectionState {
        case .connected:    return .green
        case .connecting:   return .yellow
        case .disconnected: return .red
        }
    }

    private var connectionLabel: String {
        switch relay.connectionState {
        case .connected:    return "Connected"
        case .connecting:   return "Connecting…"
        case .disconnected: return "Disconnected"
        }
    }

    // MARK: - Reconnecting banner

    @ViewBuilder
    private var reconnectingBanner: some View {
        if relay.connectionState == .connecting {
            HStack(spacing: 8) {
                ProgressView().controlSize(.mini)
                Text("Reconnecting…")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Color(UIColor.systemYellow).opacity(0.15))
        } else if relay.connectionState == .disconnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12))
                Text("Disconnected")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button("Retry") { relay.connect() }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color(UIColor.systemRed).opacity(0.1))
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var terminalTab: some View {
        if let session = activeSession {
            VStack(spacing: 0) {
                RemoteTerminalView(session: session)
                    .id(session.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                QuickCommandBar { bytes in
                    relay.sendInput(sessionID: session.id, data: Data(bytes))
                }
            }
        } else {
            noSessionPlaceholder
        }
    }

    @ViewBuilder
    private var activityTab: some View {
        if let session = activeSession {
            ActivityFeedView(session: session)
        } else {
            noSessionPlaceholder
        }
    }

    @ViewBuilder
    private var filesTab: some View {
        if let session = activeSession {
            FileBrowserView(
                agentID: session.agent.id,
                agentName: session.agent.name,
                embedded: true
            ) { path, dangerous in
                let cmd = dangerous
                    ? "cd \"\(path)\" && claude --dangerously-skip-permissions"
                    : "cd \"\(path)\" && claude"
                sessionManager.createSession(for: session.agent, initialCommand: cmd)
                activeTab = .terminal
            }
            .environmentObject(relay)
        } else {
            noSessionPlaceholder
        }
    }

    private var noSessionPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "desktopcomputer.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No active session")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Machine selector sheet

    private var machineSelectorSheet: some View {
        NavigationView {
            List {
                Section("Active Sessions") {
                    ForEach(sessionManager.sessions) { session in
                        Button {
                            selectedSessionID = session.id
                            showMachineSelector = false
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.agent.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(String(session.id.prefix(8)) + "…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fontDesign(.monospaced)
                                }
                                Spacer()
                                if session.id == activeSession?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Close", role: .destructive) {
                                closeSession(session)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showMachineSelector = false
                        // Small delay so the sheet dismisses before the next one opens
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showAddAgent = true
                        }
                    } label: {
                        Label("Add Machine", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }

                    if !sessionManager.sessions.isEmpty {
                        Button("Close All", role: .destructive) {
                            showMachineSelector = false
                            sessionManager.closeAll()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showMachineSelector = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func closeSession(_ session: TerminalSession) {
        relay.sendDisconnect(sessionID: session.id)
        sessionManager.remove(session: session)
        if selectedSessionID == session.id {
            selectedSessionID = sessionManager.sessions.first?.id
        }
    }
}
