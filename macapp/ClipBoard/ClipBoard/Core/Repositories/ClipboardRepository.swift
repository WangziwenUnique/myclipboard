import Foundation

protocol ClipboardRepository {
    func save(_ item: ClipboardItem) throws -> ClipboardItem
    func delete(_ id: Int64) throws
    func loadAll() throws -> [ClipboardItem]
    func search(query: String) throws -> [ClipboardItem]
    func getByCategory(_ category: ClipboardCategory) throws -> [ClipboardItem]
    func getSortedItems(for category: ClipboardCategory, sortOption: SortOption, isReversed: Bool) throws -> [ClipboardItem]
    func incrementCopyCount(_ id: Int64) throws
    func updateFavoriteStatus(_ id: Int64, isFavorite: Bool) throws
    func getCount() throws -> Int
    func getDistinctSourceApps() throws -> [String]
}