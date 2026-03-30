import Carbon
import AppKit

struct InputMethodUtils {

    static func currentInputSource() -> TISInputSource {
        return TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    }

    static func inputSourceID(_ source: TISInputSource) -> String {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return ""
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    static func isCJKInputSource(_ source: TISInputSource) -> Bool {
        let id = inputSourceID(source)
        let cjkPatterns = [
            "SCIM", "TCIM", "Japanese", "Korean", "Pinyin",
            "Wubi", "Cangjie", "Zhuyin", "Romaji", "Hiragana",
            "Katakana", "Hangul", "Sougou", "Baidu", "QIM",
            "inputmethod.Chinese", "inputmethod.Korean", "inputmethod.Japanese",
        ]
        return cjkPatterns.contains { id.localizedCaseInsensitiveContains($0) }
    }

    static func switchToASCII() {
        guard let sources = TISCreateInputSourceList(
            [kTISPropertyInputSourceID: "com.apple.keylayout.ABC"] as CFDictionary,
            false
        )?.takeRetainedValue() as? [TISInputSource],
              let abc = sources.first else {
            // Fallback: try US keyboard
            if let usSources = TISCreateInputSourceList(
                [kTISPropertyInputSourceID: "com.apple.keylayout.US"] as CFDictionary,
                false
            )?.takeRetainedValue() as? [TISInputSource],
               let us = usSources.first {
                TISSelectInputSource(us)
            }
            return
        }
        TISSelectInputSource(abc)
    }

    static func switchTo(_ source: TISInputSource) {
        TISSelectInputSource(source)
    }
}
