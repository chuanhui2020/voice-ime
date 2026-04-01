import Foundation

class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedLocale = "selectedLocale"
        static let llmEnabled = "llmEnabled"
        static let llmBaseURL = "llmBaseURL"
        static let llmAPIKey = "llmAPIKey"
        static let llmModel = "llmModel"
        static let customDictionary = "customDictionary"
    }

    var selectedLocale: String {
        get { defaults.string(forKey: Keys.selectedLocale) ?? "zh-CN" }
        set { defaults.set(newValue, forKey: Keys.selectedLocale) }
    }

    var llmEnabled: Bool {
        get { defaults.bool(forKey: Keys.llmEnabled) }
        set { defaults.set(newValue, forKey: Keys.llmEnabled) }
    }

    var llmBaseURL: String {
        get { defaults.string(forKey: Keys.llmBaseURL) ?? "" }
        set { defaults.set(newValue, forKey: Keys.llmBaseURL) }
    }

    var llmAPIKey: String {
        get { defaults.string(forKey: Keys.llmAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Keys.llmAPIKey) }
    }

    var llmModel: String {
        get { defaults.string(forKey: Keys.llmModel) ?? "" }
        set { defaults.set(newValue, forKey: Keys.llmModel) }
    }

    var isLLMConfigured: Bool {
        !llmBaseURL.isEmpty && !llmAPIKey.isEmpty && !llmModel.isEmpty
    }

    var customDictionary: String {
        get { defaults.string(forKey: Keys.customDictionary) ?? "铺洗/不吸/复习/噗嘻/浦西 + 到远程 → push到远程\n铺洗/不吸/复习/噗嘻/浦西 → push" }
        set { defaults.set(newValue, forKey: Keys.customDictionary) }
    }
}
