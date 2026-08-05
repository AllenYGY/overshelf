import Foundation
import SwiftUI
import Cocoa

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var appKitName: NSAppearance.Name? {
        switch self {
        case .system: return nil
        case .light: return .aqua
        case .dark: return .darkAqua
        }
    }
}

/// Which panel this is.
enum PanelType: String, Codable, CaseIterable, Identifiable {
    case clipboard
    case files
    case notes
    case todo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .files: return "Files"
        case .notes: return "Notes"
        case .todo: return "Todo"
        }
    }

    var iconName: String {
        switch self {
        case .clipboard: return "clipboard"
        case .files: return "tray.full"
        case .notes: return "note.text"
        case .todo: return "checklist"
        }
    }
}

/// Persisted app-level settings.
struct AppSettingsData: Codable {
    var panelOrder: [PanelType] = [.clipboard, .files, .notes, .todo]
    var panelWidths: [PanelType: CGFloat] = [.clipboard: 260, .files: 240, .notes: 280, .todo: 260]
    var hiddenPanels: Set<PanelType> = []
    var windowOpacity: Double = 1.0
    var windowHeight: CGFloat = 420
    var appearanceMode: AppearanceMode? = .system
    var edgeTriggerEnabled: Bool = true
    var dragToEdgeEnabled: Bool = true
    var hotkeyCode: UInt32 = 8 // C key
    var hotkeyModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue) // cmd + shift
    var keepOnTop: Bool = true
    var clipboardHistoryLimit: Int = 500
}

/// Observable wrapper around AppSettingsData.
@Observable
final class AppSettings {
    var data: AppSettingsData
    private let persistence: PersistenceManager
    
    init(persistence: PersistenceManager) {
        self.persistence = persistence
        self.data = persistence.load(AppSettingsData.self, forKey: "settings") ?? AppSettingsData()
        migrateIfNeeded()
    }

    var panelOrder: [PanelType] {
        get { data.panelOrder }
        set { data.panelOrder = newValue; save() }
    }

    var panelWidths: [PanelType: CGFloat] {
        get { data.panelWidths }
        set { data.panelWidths = newValue; save() }
    }

    var hiddenPanels: Set<PanelType> {
        get { data.hiddenPanels }
        set { data.hiddenPanels = newValue; save() }
    }

    var windowOpacity: Double {
        get { data.windowOpacity }
        set { data.windowOpacity = newValue; save() }
    }

    var windowHeight: CGFloat {
        get { data.windowHeight }
        set { data.windowHeight = newValue; save() }
    }

    var appearanceMode: AppearanceMode {
        get { data.appearanceMode ?? .system }
        set { data.appearanceMode = newValue; save() }
    }

    var edgeTriggerEnabled: Bool {
        get { data.edgeTriggerEnabled }
        set { data.edgeTriggerEnabled = newValue; save() }
    }

    var dragToEdgeEnabled: Bool {
        get { data.dragToEdgeEnabled }
        set { data.dragToEdgeEnabled = newValue; save() }
    }

    var hotkeyCode: UInt32 {
        get { data.hotkeyCode }
        set { data.hotkeyCode = newValue; save() }
    }

    var hotkeyModifiers: UInt32 {
        get { data.hotkeyModifiers }
        set { data.hotkeyModifiers = newValue; save() }
    }

    var keepOnTop: Bool {
        get { data.keepOnTop }
        set { data.keepOnTop = newValue; save() }
    }

    var clipboardHistoryLimit: Int {
        get { data.clipboardHistoryLimit }
        set { data.clipboardHistoryLimit = newValue; save() }
    }

    var visiblePanels: [PanelType] {
        data.panelOrder.filter { !data.hiddenPanels.contains($0) }
    }

    static func visiblePanels(from order: [PanelType], hidden: Set<PanelType>, detached: Set<PanelType>) -> [PanelType] {
        order.filter { !hidden.contains($0) && !detached.contains($0) }
    }

    private func migrateIfNeeded() {
        var changed = false
        if data.appearanceMode == nil {
            data.appearanceMode = .system
            changed = true
        }
        for panel in PanelType.allCases {
            if !data.panelOrder.contains(panel) {
                data.panelOrder.append(panel)
                changed = true
            }
            if data.panelWidths[panel] == nil {
                data.panelWidths[panel] = defaultWidth(for: panel)
                changed = true
            }
        }
        if changed {
            save()
        }
    }

    private func defaultWidth(for panel: PanelType) -> CGFloat {
        switch panel {
        case .clipboard: return 260
        case .files: return 240
        case .notes: return 280
        case .todo: return 260
        }
    }

    private func save() {
        persistence.save(data, forKey: "settings")
    }
}
