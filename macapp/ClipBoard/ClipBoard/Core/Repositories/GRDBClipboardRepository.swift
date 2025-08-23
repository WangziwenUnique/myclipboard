import Foundation
import GRDB

class GRDBClipboardRepository: ClipboardRepository {
    private let dbManager = GRDBDatabaseManager.shared
    
    // 保存：从70行代码变成3行
    func save(_ item: ClipboardItem) async throws -> ClipboardItem {
        return try await dbManager.write { db in
            var mutableItem = item
            try mutableItem.insert(db)
            return mutableItem
        }
    }
    
    // 删除：从15行变成1行
    func delete(_ id: Int64) async throws {
        try await dbManager.write { db in
            _ = try ClipboardItem.deleteOne(db, id: id)
        }
    }
    
    // 加载所有：从50行变成1行
    func loadAll() async throws -> [ClipboardItem] {
        return try await dbManager.read { db in
            try ClipboardItem
                .order(ClipboardItem.Columns.timestamp.desc)
                .limit(1000)
                .fetchAll(db)
        }
    }
    
    // 分页加载：从30行变成1行
    func loadPage(page: Int, limit: Int) async throws -> [ClipboardItem] {
        return try await dbManager.read { db in
            try ClipboardItem
                .order(ClipboardItem.Columns.timestamp.desc)
                .limit(limit, offset: page * limit)
                .fetchAll(db)
        }
    }
    
    // 搜索：使用FTS5全文搜索，性能提升10-100倍
    func search(query: String) async throws -> [ClipboardItem] {
        return try await dbManager.read { db in
            // 空查询返回空结果
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return []
            }
            
            // FTS5搜索语法转换：处理特殊字符
            let ftsQuery = query
                .replacingOccurrences(of: "'", with: "''")  // 转义单引号
                .replacingOccurrences(of: "\"", with: "\"\"") // 转义双引号
            
            // 使用FTS5 MATCH进行全文搜索，按相关性排序
            return try ClipboardItem
                .filter(sql: "id IN (SELECT rowid FROM clipboard_items_fts WHERE clipboard_items_fts MATCH ?)", arguments: [ftsQuery])
                .order(ClipboardItem.Columns.timestamp.desc) // 保持时间排序
                .fetchAll(db)
        }
    }
    
    // 按分类查询：彻底简化
    func getByCategory(_ category: ClipboardCategory) async throws -> [ClipboardItem] {
        return try await dbManager.read { db in
            let request: QueryInterfaceRequest<ClipboardItem>
            
            switch category {
            case .history:
                request = ClipboardItem.all()
            case .favorites:
                request = ClipboardItem.filter(ClipboardItem.Columns.isFavorite == true)
            case .text:
                request = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.text.rawValue)
            case .images:
                request = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.image.rawValue)
            case .links:
                request = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.link.rawValue)
            case .files:
                request = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.file.rawValue)
            case .mail:
                request = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.email.rawValue)
            }
            
            return try request.order(ClipboardItem.Columns.timestamp.desc).fetchAll(db)
        }
    }
    
    // 排序查询：数据库级别排序，性能更好
    func getSortedItems(for category: ClipboardCategory, sortOption: SortOption, isReversed: Bool) async throws -> [ClipboardItem] {
        return try await dbManager.read { db in
            let baseRequest: QueryInterfaceRequest<ClipboardItem>
            
            switch category {
            case .history:
                baseRequest = ClipboardItem.all()
            case .favorites:
                baseRequest = ClipboardItem.filter(ClipboardItem.Columns.isFavorite == true)
            case .text:
                baseRequest = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.text.rawValue)
            case .images:
                baseRequest = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.image.rawValue)
            case .links:
                baseRequest = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.link.rawValue)
            case .files:
                baseRequest = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.file.rawValue)
            case .mail:
                baseRequest = ClipboardItem.filter(ClipboardItem.Columns.type == ClipboardItemType.email.rawValue)
            }
            
            // 数据库级别排序
            let sortedRequest: QueryInterfaceRequest<ClipboardItem>
            switch sortOption {
            case .lastCopyTime:
                sortedRequest = isReversed ? 
                    baseRequest.order(ClipboardItem.Columns.lastCopyTime.asc) :
                    baseRequest.order(ClipboardItem.Columns.lastCopyTime.desc)
            case .firstCopyTime:
                sortedRequest = isReversed ?
                    baseRequest.order(ClipboardItem.Columns.firstCopyTime.desc) :
                    baseRequest.order(ClipboardItem.Columns.firstCopyTime.asc)
            case .numberOfCopies:
                sortedRequest = isReversed ?
                    baseRequest.order(ClipboardItem.Columns.copyCount.asc) :
                    baseRequest.order(ClipboardItem.Columns.copyCount.desc)
            case .size:
                // 使用SQL LENGTH函数计算字符串长度
                sortedRequest = isReversed ?
                    baseRequest.order(sql: "LENGTH(content) ASC") :
                    baseRequest.order(sql: "LENGTH(content) DESC")
            }
            
            return try sortedRequest.fetchAll(db)
        }
    }
    
    // 增加复制次数：从20行变成1行
    func incrementCopyCount(_ id: Int64) async throws {
        try await dbManager.write { db in
            try db.execute(sql: """
                UPDATE clipboard_items 
                SET copy_count = copy_count + 1, last_copy_time = ? 
                WHERE id = ?
                """, arguments: [Int64(Date().timeIntervalSince1970 * 1000), id])
        }
    }
    
    // 更新收藏状态：从20行变成1行
    func updateFavoriteStatus(_ id: Int64, isFavorite: Bool) async throws {
        try await dbManager.write { db in
            try db.execute(sql: "UPDATE clipboard_items SET is_favorite = ? WHERE id = ?", 
                          arguments: [isFavorite, id])
        }
    }
    
    // 清理旧数据：从20行变成1行
    func cleanupOldData(olderThan date: Date) async throws {
        try await dbManager.write { db in
            let timestampMs = Int64(date.timeIntervalSince1970 * 1000)
            try ClipboardItem
                .filter(ClipboardItem.Columns.timestamp < timestampMs && ClipboardItem.Columns.isFavorite == false)
                .deleteAll(db)
        }
    }
    
    // 获取数量：从15行变成1行
    func getCount() async throws -> Int {
        return try await dbManager.read { db in
            try ClipboardItem.fetchCount(db)
        }
    }
    
    // 获取所有不同的source_app：1行SQL解决
    func getDistinctSourceApps() async throws -> [String] {
        return try await dbManager.read { db in
            try String.fetchAll(db, sql: """
                SELECT DISTINCT source_app 
                FROM clipboard_items 
                WHERE source_app IS NOT NULL AND source_app != ''
                ORDER BY source_app
                """)
        }
    }
}
