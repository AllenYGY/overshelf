import SwiftUI

/// Shared visual constants for the DropShelf UI.
enum Theme {
    static let panelBg = Color.clear // content uses .ultraThinMaterial
    static let sidebarBg = Color(nsColor: .controlBackgroundColor).opacity(0.5)
    static let rowHover = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    static let rowSelected = Color(nsColor: .selectedContentBackgroundColor)
    static let divider = Color(nsColor: .separatorColor)
    static let secondaryText = Color.secondary
    static let headerHeight: CGFloat = 32
    static let minPanelWidth: CGFloat = 160
    static let dividerWidth: CGFloat = 1.0
    static let dividerHitWidth: CGFloat = 8.0
}

/// A compact panel header with title and optional action buttons.
struct PanelHeader: View {
    let title: String
    let iconName: String
    var onDetach: (() -> Void)?
    var onReattach: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            if let onReattach {
                Button(action: onReattach) {
                    Image(systemName: "arrow.down.left.square")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reattach panel")
            }
            if let onDetach {
                Button(action: onDetach) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Detach panel")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Theme.headerHeight)
        .background(Theme.sidebarBg)
    }
}

/// A draggable divider between panels.
struct PanelDivider: View {
    let onDrag: (CGFloat) -> Void
    @State private var lastTranslation: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(width: 1)
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: Theme.dividerHitWidth)
                    .contentShape(Rectangle())
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let delta = value.translation.width - lastTranslation
                        lastTranslation = value.translation.width
                        onDrag(delta)
                    }
                    .onEnded { _ in
                        lastTranslation = 0
                    }
            )
    }
}

/// A rounded rect background for the window content.
struct WindowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}
