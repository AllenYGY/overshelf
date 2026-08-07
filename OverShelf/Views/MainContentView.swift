import SwiftUI

/// The main dropdown content: panels side-by-side with adjustable dividers.
struct MainContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(UIState.self) private var uiState
    @State private var heightDragBase: CGFloat?

    var visiblePanels: [PanelType] {
        AppSettings.visiblePanels(from: settings.panelOrder, hidden: settings.hiddenPanels)
    }

    var body: some View {
        @Bindable var settings = settings

        ZStack(alignment: .topTrailing) {
            WindowBackground()

            GeometryReader { geometry in
                let dividerWidth = CGFloat(max(0, visiblePanels.count - 1)) * Theme.dividerWidth
                let widths = PanelLayout.widths(
                    for: visiblePanels,
                    preferred: settings.panelWidths,
                    totalWidth: max(0, geometry.size.width - dividerWidth),
                    minWidth: Theme.minPanelWidth
                )
                HStack(spacing: 0) {
                    ForEach(Array(visiblePanels.enumerated()), id: \.element) { index, panel in
                        panelView(for: panel)
                            .frame(width: widths[panel], height: geometry.size.height)

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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Keep panel management available without reserving layout width.
            panelManager()

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
    }

    @ViewBuilder
    private func panelManager() -> some View {
        Menu {
            ForEach(settings.panelOrder) { panel in
                let visible = !settings.hiddenPanels.contains(panel)
                Button {
                    var hidden = settings.hiddenPanels
                    if visible {
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
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .background(Theme.sidebarBg)
        .help("Panels")
        .padding(.top, 2)
        .padding(.trailing, 2)
    }

    @ViewBuilder
    private func panelView(for panel: PanelType) -> some View {
        switch panel {
        case .clipboard: ClipboardPanelView()
        case .files: FilesPanelView()
        case .notes: NotesPanelView()
        case .todo: TodoPanelView()
        case .workspaces: WorkspacesPanelView()
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
