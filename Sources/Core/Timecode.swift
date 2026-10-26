import Foundation

public enum Timecode {
    /// `m:ss`, or `h:mm:ss` from one hour. Negative or non-finite values show as zero.
    public static func string(_ seconds: Double) -> String {
        let total = seconds.isFinite ? max(0, Int(seconds)) : 0
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
