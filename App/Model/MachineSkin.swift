import Foundation

enum MachineSkin: String, CaseIterable, Identifiable {
    case original, studio, glass

    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original 808"
        case .studio: return "Studio 808"
        case .glass: return "Digital 808"
        }
    }
    var detail: String {
        switch self {
        case .original: return "The complete original front panel"
        case .studio: return "Tactile controls arranged for your phone"
        case .glass: return "Native Liquid Glass in the 808 palette"
        }
    }
    var symbol: String {
        switch self {
        case .original: return "pianokeys"
        case .studio: return "dial.medium"
        case .glass: return "circle.hexagongrid"
        }
    }
}
