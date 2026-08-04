import SwiftUI

/// The main dropdown content: three panels side-by-side with adjustable dividers.
struct MainContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(UIState.self) private var uiState
    @Environment(ClipboardMonitor.self) private var clipboard
    @Environment(NotesManager.self) private var notes
    @Environment(FileStagingManager.self) private var files
    @Environment(TodoManager.self) private var todos
    @State private var heightDragBase: CGFloat?

    var visiblePanels: [PanelType] {
        AppSettings.visiblePanels(from: settings.panelOrder, hidden: settings.hiddenPanels, detached: uiState.detachedPanels)
    }

    var body: some View {
        @Bindable var settings = settings

        ZStack {
            WindowBackground()

            HStack(spacing: 0) {
                ForEach(Array(visiblePanels.enumerated()), id: \.element) { index, panel in
                    panelView(for: panel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if index < visiblePanels.count - 1 {
                        PanelDivider { delta in
                            adjustWidth(
                                left: visiblePanels[index],
                                right: visiblePanels[index + 1],
                                delta: delta
                            )
                        }
                    }
                }

                // Always-visible panel manager so hidden panels can be restored.
                Menu {
                    ForEach(settings.panelOrder) { panel in
                        let detached = uiState.detachedPanels.contains(panel)
                        let visible = !settings.hiddenPanels.contains(panel)
                        if detached {
                            Button {
                                uiState.onReattachPanel?(panel)
                            } label: {
                                Label("Reattach \(panel.title)", systemImage: "arrow.down.left.square")
                            }
                        } else {
                            Button {
                                var hidden = settings.hiddenPanels
                                if visible {
                                    // Keep at least one panel visible.
                                    if settings.panelOrder.count - settings.hiddenPanels.count > 1 {
                                        hidden.insert(panel)
                                    }
                                } else {
                                    hidden.remove(panel)
                                }
                                settings.hiddenPanels = hidden
                            } label: {
                                Label(panel.title, systemImage: visible ? "checkmark" : "minus")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 36)
                .background(Theme.sidebarBg)
                .help("Panels")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Bottom drag handle for live height resize (persisted on release).
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 40, height: 3)
                    Spacer()
                }
                .frame(height: 8)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if heightDragBase == nil {
                                heightDragBase = settings.windowHeight
                            }
                            let h = min(700, max(280, heightDragBase! + value.translation.height))
                            uiState.onLiveHeightChange?(h)
                        }
                        .onEnded { value in
                            let base = heightDragBase ?? settings.windowHeight
                            let h = min(700, max(280, base + value.translation.height))
                            settings.windowHeight = h
                            heightDragBase = nil
                        }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .detachPanel)) { note in
            if let panel = note.userInfo?["panel"] as? PanelType {
                NotificationCenter.default.post(name: .windowDetach, object: nil, userInfo: ["panel": panel])
            }
        }
    }

    @ViewBuilder
    private func panelView(for panel: PanelType) -> some View {
        switch panel {
        case .clipboard: ClipboardPanelView()
        case .files: FilesPanelView()
        case .notes: NotesPanelView()
        case .todo: TodoPanelView()
        }
    }

    private func adjustWidth(left: PanelType, right: PanelType, delta: CGFloat) {
        var widths = settings.panelWidths
        let leftWidth = widths[left] ?? 250
        let rightWidth = widths[right] ?? 250

        let newLeft = max(Theme.minPanelWidth, leftWidth + delta)
        let actualDelta = newLeft - leftWidth
        let newRight = max(Theme.minPanelWidth, rightWidth - actualDelta)

        widths[left] = newLeft
        widths[right] = newRight
        settings.panelWidths = widths
    }
}

extension Notification.Name {
    static let windowDetach = Notification.Name("windowDetach")
}
