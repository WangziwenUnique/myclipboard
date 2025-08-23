import Foundation

enum SortOption: CaseIterable {
    case lastCopyTime
    case firstCopyTime
    case numberOfCopies
    case size
    
    var displayName: String {
        switch self {
        case .lastCopyTime: return "Last Copy Time"
        case .firstCopyTime: return "First Copy Time"
        case .numberOfCopies: return "Number of Copies"
        case .size: return "Size"
        }
    }
}

struct SortConfiguration: Equatable {
    var option: SortOption = .lastCopyTime
    var isReversed: Bool = false
    
    mutating func toggleReverse() {
        isReversed.toggle()
    }
}