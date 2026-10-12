import Foundation

enum AppTheme: String { case refinedLight, techDark
    var title: String { self == .refinedLight ? "简洁精致" : "深色科技" }
}
final class AppSettings {
    static let shared = AppSettings()
    private let defaults: UserDefaults
    var changed: (() -> Void)?
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var parallelGeneration: Bool {
        get { defaults.object(forKey: "parallelGeneration") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "parallelGeneration"); changed?() }
    }
    var modelId: String {
        get { defaults.string(forKey: "selectedModelId") ?? "hy3" }
        set { defaults.set(newValue, forKey: "selectedModelId"); changed?() }
    }
    var models: [String] {
        get { defaults.stringArray(forKey: "modelCatalog") ?? ["hy3"] }
        set { defaults.set(newValue, forKey: "modelCatalog"); changed?() }
    }
    var theme: AppTheme {
        get { AppTheme(rawValue: defaults.string(forKey: "themeId") ?? "") ?? .refinedLight }
        set { defaults.set(newValue.rawValue, forKey: "themeId"); changed?() }
    }
    func shortcut(_ mode: TaskMode) -> (key: UInt32, modifiers: UInt32) {
        let name = mode.rawValue
        return (UInt32(defaults.object(forKey: name + "Key") as? Int ?? (mode == .translation ? 2 : 14)), UInt32(defaults.object(forKey: name + "Modifiers") as? Int ?? 0x0800))
    }
    func saveShortcut(_ mode: TaskMode, key: UInt32, modifiers: UInt32) {
        defaults.set(Int(key), forKey: mode.rawValue + "Key")
        defaults.set(Int(modifiers), forKey: mode.rawValue + "Modifiers")
    }
}
