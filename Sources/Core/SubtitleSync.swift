import Foundation

/// Subtitle timing offset for mpv's `sub-delay`: a positive value shows captions later.
public enum SubtitleSync {
    public static let limit = 5.0
    public static let step = 0.5

    public static func clamped(_ seconds: Double) -> Double { min(max(seconds, -limit), limit) }

    /// One step earlier (`direction` < 0) or later (> 0), snapped to the step grid and kept within the limit.
    public static func stepped(_ seconds: Double, by direction: Int) -> Double {
        let current = (clamped(seconds) / step).rounded() * step
        return clamped(current + Double(direction.signum()) * step)
    }

    /// False when a step in `direction` would not change the offset.
    public static func canStep(_ seconds: Double, by direction: Int) -> Bool {
        stepped(seconds, by: direction) != clamped(seconds)
    }

    /// "+1.5 s", "-0.5 s" or "0.0 s".
    public static func label(_ seconds: Double) -> String {
        let rounded = (clamped(seconds) * 10).rounded() / 10
        if rounded == 0 { return "0.0 s" }
        return String(format: "%+.1f s", rounded)
    }
}
