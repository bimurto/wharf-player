import Foundation

/// Subtitle size (mpv `sub-scale`, 1.0 = 100%) and vertical position (mpv `sub-pos`, 100 = bottom, lower = higher up).
public enum SubtitleAppearance {
    public static let scaleRange = 0.75...2.0
    public static let defaultScale = 1.0
    public static let scaleStep = 0.1
    public static let positionRange = 50.0...100.0
    public static let defaultPosition = 100.0
    public static let positionStep = 5.0

    public static func clampedScale(_ v: Double) -> Double {
        guard v.isFinite else { return defaultScale }
        return min(max(v, scaleRange.lowerBound), scaleRange.upperBound)
    }

    public static func clampedPosition(_ v: Double) -> Double {
        guard v.isFinite else { return defaultPosition }
        return min(max(v, positionRange.lowerBound), positionRange.upperBound)
    }

    /// One step smaller (`direction` < 0) or bigger (> 0), within 75% to 200%.
    public static func steppedScale(_ v: Double, by direction: Int) -> Double {
        let next = clampedScale(v) + Double(direction.signum()) * scaleStep
        return (clampedScale(next) * 100).rounded() / 100
    }

    public static func canStepScale(_ v: Double, by direction: Int) -> Bool {
        steppedScale(v, by: direction) != clampedScale(v)
    }

    /// One step up (smaller `sub-pos`) or down (bigger), within the position range.
    public static func steppedPosition(_ v: Double, up: Bool) -> Double {
        clampedPosition(clampedPosition(v) + (up ? -positionStep : positionStep))
    }

    public static func canStepPosition(_ v: Double, up: Bool) -> Bool {
        steppedPosition(v, up: up) != clampedPosition(v)
    }

    /// "100%", "125%".
    public static func scaleLabel(_ v: Double) -> String { "\(Int((clampedScale(v) * 100).rounded()))%" }

    /// "Bottom" at the default, else "10% up".
    public static func positionLabel(_ v: Double) -> String {
        let up = Int((defaultPosition - clampedPosition(v)).rounded())
        return up == 0 ? "Bottom" : "\(up)% up"
    }
}

/// The saved subtitle size and position in `UserDefaults`; values read back are always within range.
public final class SubtitleAppearanceStore {
    private let defaults: UserDefaults
    private let scaleKey = "subtitle_scale"
    private let positionKey = "subtitle_position"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var scale: Double {
        get {
            defaults.object(forKey: scaleKey) == nil
                ? SubtitleAppearance.defaultScale
                : SubtitleAppearance.clampedScale(defaults.double(forKey: scaleKey))
        }
        set { defaults.set(SubtitleAppearance.clampedScale(newValue), forKey: scaleKey) }
    }

    public var position: Double {
        get {
            defaults.object(forKey: positionKey) == nil
                ? SubtitleAppearance.defaultPosition
                : SubtitleAppearance.clampedPosition(defaults.double(forKey: positionKey))
        }
        set { defaults.set(SubtitleAppearance.clampedPosition(newValue), forKey: positionKey) }
    }

    public func reset() {
        defaults.removeObject(forKey: scaleKey)
        defaults.removeObject(forKey: positionKey)
    }
}
