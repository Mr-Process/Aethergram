import SwiftUI
import CoreText
#if os(macOS)
import AppKit
#endif

/// Manages Materialgram typography (Google Sans primary, Vazirmatn for Arabic)
/// with runtime CoreText registration and clean macOS system fallbacks.
public enum MD3Typography {
    public static let primaryFontName = "Google Sans"
    public static let arabicFontName = "Vazirmatn"

    /// Safely locates the MaterialgramKit resource bundle without invoking SwiftPM's
    /// fatalError-throwing `Bundle.module` accessor when packaged into a macOS `.app`.
    public static var resourceBundle: Bundle {
        let bundleNames = [
            "AethergramMac_AethergramKit.bundle",
            "MaterialgramMac_MaterialgramKit.bundle"
        ]
        for bundleName in bundleNames {
            let candidates: [URL?] = [
                Bundle.main.resourceURL?.appendingPathComponent(bundleName),
                Bundle.main.bundleURL.appendingPathComponent(bundleName),
                Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(bundleName)
            ]
            for case let url? in candidates {
                if let bundle = Bundle(url: url) {
                    return bundle
                }
            }
        }
        return Bundle.main
    }

    public static func registerBundledFonts() {
        let bundle = resourceBundle
        let extensions = ["ttf", "otf"]
        for ext in extensions {
            if let urls = bundle.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") {
                for url in urls {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
    }

    public static var isGoogleSansAvailable: Bool {
        #if os(macOS)
        return NSFont(name: primaryFontName, size: 13) != nil
        #else
        return false
        #endif
    }

    public static var isVazirmatnAvailable: Bool {
        #if os(macOS)
        return NSFont(name: arabicFontName, size: 13) != nil
        #else
        return false
        #endif
    }

    public static func resolvedFontFamilyName(forSampleText text: String = "") -> String {
        let hasArabic = text.unicodeScalars.contains { scalar in
            (0x0600...0x06FF).contains(scalar.value) || (0x0750...0x077F).contains(scalar.value)
        }
        if hasArabic && isVazirmatnAvailable {
            return arabicFontName
        }
        if isGoogleSansAvailable {
            return primaryFontName
        }
        return "SF Pro Rounded"
    }
}

public extension Font {
    static func mgFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if MD3Typography.isGoogleSansAvailable {
            return .custom(MD3Typography.primaryFontName, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}
