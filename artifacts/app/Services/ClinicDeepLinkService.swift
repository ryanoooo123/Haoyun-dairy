import Foundation
import UIKit

final class ClinicDeepLinkService {
    static let shared = ClinicDeepLinkService()
    private init() {}

    /// LINE OA ID from Info.plist (key: ClinicLineOAID). Empty string if unset.
    var lineOAID: String {
        (Bundle.main.object(forInfoDictionaryKey: "ClinicLineOAID") as? String) ?? "@haoyunclinic"
    }

    /// Fallback web booking URL from Info.plist (key: ClinicWebBookingURL).
    var webBookingURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "ClinicWebBookingURL") as? String)
            ?? "https://haoyun.example.tw/booking"
    }

    /// Tries to open LINE OA via the `line://` URL scheme; if LINE is not installed,
    /// falls back to the clinic's web booking URL via Safari.
    /// canOpenURL on `https://` URLs always returns true (reachable), so we must probe
    /// the `line://` scheme (requires `line` in LSApplicationQueriesSchemes) to detect LINE.
    /// Returns true if some URL was successfully opened.
    @MainActor
    func openBookingLink() async -> Bool {
        let encodedID = lineOAID.replacingOccurrences(of: "@", with: "%40")

        // Step 1: probe whether LINE is installed via its custom scheme.
        if let lineProbe = URL(string: "line://ti/p/\(encodedID)"),
           UIApplication.shared.canOpenURL(lineProbe) {
            // Open the universal https://line.me/R/ti/p/... URL so LINE's universal-link
            // handler deep-links into the app (more reliable than pure scheme on newer iOS).
            if let lineUniversal = URL(string: "https://line.me/R/ti/p/\(encodedID)") {
                let ok = await UIApplication.shared.open(lineUniversal)
                if ok { return true }
            }
            // If the universal URL somehow failed to open, try the scheme URL directly.
            let ok = await UIApplication.shared.open(lineProbe)
            if ok { return true }
        }

        // Step 2: LINE is not installed (or universal link failed); fall through to the web URL.
        guard let webURL = URL(string: webBookingURL) else { return false }
        return await UIApplication.shared.open(webURL)
    }
}
