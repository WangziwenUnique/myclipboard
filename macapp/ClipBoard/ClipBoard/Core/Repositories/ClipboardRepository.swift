import Foundation

protocol ClipboardRepository {
    func save(_ item: ClipboardItem) async throws
    func delete(_ id: UUID) async throws
    func loadAll() async throws -> [ClipboardItem]
    func search(query: String) async throws -> [ClipboardItem]
    func getByCategory(_ category: ClipboardCategory) async throws -> [ClipboardItem]
    func getSortedItems(for category: ClipboardCategory, sortOption: SortOption, isReversed: Bool) async throws -> [ClipboardItem]
    func incrementCopyCount(_ id: UUID) async throws
    func updateFavoriteStatus(_ id: UUID, isFavorite: Bool) async throws
    func cleanupOldData(olderThan date: Date) async throws
    func getCount() async throws -> Int
}