//
//  FirstLaunchGuideLogic.swift
//  Track21
//
//  One-time "how to use Track 21" guide. Fresh installs see it on Home
//  after welcome/auth and buddy naming. The old intro carousel is gone.
//  People who already finished that carousel before this shipped are
//  marked seen so the new guide never blocks them.
//

import Foundation

enum FirstLaunchGuideLogic {
    static let seenKey = "Track21HasSeenFirstLaunchGuide"
    static let migratedKey = "Track21FirstLaunchGuideMigrated"
    /// Legacy carousel flag. Still read once so returning users who already
    /// passed the old intro are not stopped by the new guide.
    static let onboardingKey = "Track21HasSeenOnboarding"

    /// Runs once. If the old intro carousel was already completed, this user
    /// is returning and must not be stopped by the new guide. A fresh install
    /// has not seen it, so the guide stays eligible until they finish or skip.
    static func migrateReturningUsersIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: migratedKey) == nil else { return }
        if defaults.bool(forKey: onboardingKey) {
            defaults.set(true, forKey: seenKey)
        }
        defaults.set(true, forKey: migratedKey)
    }

    /// Guide waits until buddy naming is done, and never repeats after
    /// finish/skip. UI-test resets suppress it unless a test explicitly
    /// asks for a fresh guide.
    static func shouldPresent(
        hasSeenGuide: Bool,
        buddyNamed: Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if arguments.contains("-preview-first-launch-guide") {
            return true
        }
        if arguments.contains("-uitest-reset"), !arguments.contains("-uitest-fresh-guide") {
            return false
        }
        return !hasSeenGuide && buddyNamed
    }
}
