import Foundation

protocol ClipboardRepository {
    func save(_ item: ClipboardItem) async throws -> ClipboardItem
    func delete(_ id: Int64) async throws
    func loadAll() async throws -> [ClipboardItem]
    func loadPage(page: Int, limit: Int) async throws -> [ClipboardItem]
    func search(query: String) async throws -> [ClipboardItem]
    func getByCategory(_ category: ClipboardCategory) async throws -> [ClipboardItem]
    func getSortedItems(for category: ClipboardCategory, sortOption: SortOption, isReversed: Bool) async throws -> [ClipboardItem]
    func incrementCopyCount(_ id: Int64) async throws
    func updateFavoriteStatus(_ id: Int64, isFavorite: Bool) async throws
    func cleanupOldData(olderThan date: Date) async throws
    func getCount() async throws -> Int
    func getDistinctSourceApps() async throws -> [String]
}