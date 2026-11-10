import Foundation

public enum PanelLayout {
    public static func height(tab: String, hasTask: Bool) -> Double {
        switch tab {
        case "music": return 230
        case "settings": return 580
        default: return hasTask ? 650 : 450
        }
    }
}
