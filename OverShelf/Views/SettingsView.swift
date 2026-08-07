import SwiftUI

/// The settings/preferences window content.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(UIState.self) private var uiState
    @Environment(ClipboardMonitor.self) private var clipboard

    var body: some View {
        @Bindable var settings = settings

        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            panelsTab
                .tabItem { Label("Panels", systemImage: "rectangle.split.3") }
            clipboardTab
                .tabItem { Label("Clipboard", systemImage: "clipboard") }
        }
        .frame(width: 460, height: 380)
    }

    // MARK: - General

    private var generalTab: some View {
        @Bindable var settings = settings

        return Form {
            Section("Triggers") {
                Toggle("Cmd + mouse at top edge", isOn: Binding(
                    get: { settings.edgeTriggerEnabled },
                    set: { uiState.onEdgeTriggerChange?($0) }
                ))
                Toggle("Drag to top edge", isOn: Binding(
                    get: { settings.dragToEdgeEnabled },
                    set: { uiState.onDragToEdgeChange?($0) }
                ))
            }

            Section("Hotkey") {
                HStack {
                    Text("Show/hide OverShelf:")
                    HotkeyRecorder(keyCode: settings.hotkeyCode, modifiers: settings.hotkeyModifiers) { code, mods in
                        uiState.onHotkeyChange?(code, mods)
                    }
                }
            }

            Section("Window") {
                Picker("Appearance", selection: Binding(
                    get: { settings.appearanceMode },
                    set: { uiState.onAppearanceChange?($0) }
                )) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Slider(value: Binding(
                    get: { settings.windowOpacity },
                    set: { uiState.onOpacityChange?($0) }
                ), in: 0.5...1.0) {
                    Text("Opacity")
                }
                Slider(value: Binding(
                    get: { Double(settings.windowHeight) },
                    set: { settings.windowHeight = CGFloat($0) }
                ), in: 280...700) {
                    Text("Window height")
                }
                Toggle("Keep on top of all windows", isOn: Binding(
                    get: { settings.keepOnTop },
                    set: { settings.keepOnTop = $0 }
                ))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Panels

    private var panelsTab: some View {
        @Bindable var settings = settings

        return Form {
            Section("Panel Order (drag to reorder)") {
                List {
                    ForEach(settings.panelOrder, id: \.self) { panel in
                        HStack {
                            Image(systemName: panel.iconName)
                                .frame(width: 20)
                            Text(panel.title)
                            Spacer()
                            let isHidden = settings.hiddenPanels.contains(panel)
                            Button(isHidden ? "Show" : "Hide") {
                                var hidden = settings.hiddenPanels
                                if hidden.contains(panel) {
                                    hidden.remove(panel)
                                } else {
                                    hidden.insert(panel)
                                }
                                // Don't allow hiding all panels
                                if settings.panelOrder.count - hidden.count > 0 {
                                    settings.hiddenPanels = hidden
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(isHidden ? Color.secondary : Color.accentColor)
                        }
                    }
                    .onMove { indices, newOffset in
                        var order = settings.panelOrder
                        order.move(fromOffsets: indices, toOffset: newOffset)
                        settings.panelOrder = order
                    }
                }
                Button("Restore all panels") {
                    settings.hiddenPanels = []
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Clipboard

    private var clipboardTab: some View {
        @Bindable var settings = settings

        return Form {
            Section("History") {
                Picker("Maximum items", selection: Binding(
                    get: { settings.clipboardHistoryLimit },
                    set: { newValue in
                        settings.clipboardHistoryLimit = newValue
                        uiState.onHistoryLimitChange?(newValue)
                    }
                )) {
                    Text("100").tag(100)
                    Text("200").tag(200)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text("Unlimited").tag(999999)
                }

                HStack {
                    Text("Current count: \(clipboard.items.count)")
                    Spacer()
                    Button("Clear history now") {
                        clipboard.clearHistory()
                    }
                    .foregroundStyle(.red)
                }
            }

            Section("About") {
                Text("OverShelf replicates the classic Mac dropdown drawer with clipboard history, file staging, and quick notes — all summoned from the top edge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// A simple hotkey recorder that captures key presses.
struct HotkeyRecorder: View {
    let keyCode: UInt32
    let modifiers: UInt32
    let onChange: (UInt32, UInt32) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    private var displayString: String {
        var parts: [String] = []
        let modFlags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if modFlags.contains(.control) { parts.append("⌃") }
        if modFlags.contains(.option) { parts.append("⌥") }
        if modFlags.contains(.shift) { parts.append("⇧") }
        if modFlags.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined(separator: " ")
    }

    var body: some View {
        Button(action: { isRecording.toggle() }) {
            HStack {
                Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                    .foregroundStyle(isRecording ? .red : .secondary)
                    .font(.system(size: 11))
                Text(isRecording ? "Press keys…" : displayString)
                    .font(.system(size: 12, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.fieldBg)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .onChange(of: isRecording) { _, recording in
            if recording {
                startRecording()
            } else {
                stopRecording()
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            let code = UInt32(event.keyCode)
            // Ignore modifier-only keys
            if event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty && (code == 54 || code == 55 || code == 56 || code == 57 || code == 58 || code == 59 || code == 60 || code == 61 || code == 62) {
                return nil
            }
            onChange(code, UInt32(mods))
            isRecording = false
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func keyCodeToString(_ code: UInt32) -> String {
        // Common key codes
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
            46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return keyMap[code] ?? "Key\(code)"
    }
}
