import Foundation

/// Looks up the Claude notch's wording in `Claude.xcstrings`, following the same
/// language the rest of the app uses (the Mac's language unless overridden in settings).
enum ClaudeText {
    /// Tests set this to get stable English output.
    nonisolated(unsafe) static var languageOverride: DynamicNotchLanguage?

    static func t(_ key: String, _ english: String) -> String {
        let language = languageOverride ?? DynamicNotchLanguage.resolved(
            UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage)
        )
        let candidates = language.bundleLanguageCandidates.isEmpty
            ? Bundle.main.preferredLocalizations
            : language.bundleLanguageCandidates

        for code in candidates {
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                let value = NSLocalizedString(key, tableName: "Claude", bundle: bundle, value: english, comment: "")
                return value == key ? english : value
            }
        }
        return english
    }

    static func f(_ key: String, _ english: String, _ argument: String) -> String {
        String(format: t(key, english), argument)
    }
}
