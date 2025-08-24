import Foundation
import GRDB

class GRDBClipboardRepository: ClipboardRepository {
    private let dbManager = GRDBDatabaseManager.shared
    
    // 双写：立即写入内存，异步写入文件
    func save(_ item: ClipboardItem) throws -> ClipboardItem {
        // 1. 同步写入内存数据库
        let memoryItem = try dbManager.writeToMemory { db in
            var mutableItem = item
            try mutableItem.insert(db)
            return mutableItem
        }
        
        // 2. 异步写入文件数据库
        Task.detached { [weak self] in
            do {
                _ = try await self?.dbManager.writeToDisk { db in
                    var diskItem = memoryItem
                    try diskItem.insert(db)
                    return diskItem
                }
            } catch {
                print("❌ 文件数据库写入失败: \(error)")
            }
        }
        
        return memoryItem
    }
    
    // 双删：立即从内存删除，异步从文件删除
    func delete(_ id: Int64) throws {
        // 1. 同步从内存数据库删除
        try dbManager.writeToMemory { db in
            _ = try ClipboardItem.deleteOne(db, id: id)
        }
        
        // 2. 异步从文件数据库删除
        Task.detached { [weak self] in
            do {
                try await self?.dbManager.writeToDisk { db in
                    _ = try ClipboardItem.deleteOne(db, id: id)
                }
            } catch {
                print("❌ 文件数据库删除失败: \(error)")
            }
        }
    }
    
    // 从内存加载所有数据
    func loadAll() throws -> [ClipboardItem] {
        return try dbManager.readFromMemory { db in
            try ClipboardItem
                .order(ClipboardItem.Columns.timestamp.desc)
                .fetchAll(db)
        }
    }
    
    // 搜索：使用内存SQLite LIKE查询，快速响应
    func search(query: String) throws -> [ClipboardItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        return try dbManager.readFromMemory { db in
            try ClipboardItem
                .filter(sql: "content LIKE ?", arguments: ["%\(query)%"])
                .order(ClipboardItem.Columns.timestamp.desc)
                .fetchAll(db)
        }
    }
    
    // 从内存按分类查询
    func getByCategory(_ category: ClipboardCategory) throws -> [ClipboardItem] {
        return try dbManager.readFromMemory { db in
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
    
    // 从内存获取排序数据
    func getSortedItems(for category: ClipboardCategory, sortOption: SortOption, isReversed: Bool) throws -> [ClipboardItem] {
        return try dbManager.readFromMemory { db in
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
                sortedRequest = isReversed ?
                    baseRequest.order(sql: "LENGTH(content) ASC") :
                    baseRequest.order(sql: "LENGTH(content) DESC")
            }
            
            return try sortedRequest.fetchAll(db)
        }
    }
    
    // 双更新：内存和文件数据库都更新复制次数
    func incrementCopyCount(_ id: Int64) throws {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        // 1. 同步更新内存数据库
        try dbManager.writeToMemory { db in
            try db.execute(sql: """
                UPDATE clipboard_items 
                SET copy_count = copy_count + 1, last_copy_time = ? 
                WHERE id = ?
                """, arguments: [timestamp, id])
        }
        
        // 2. 异步更新文件数据库
        Task.detached { [weak self] in
            do {
                try await self?.dbManager.writeToDisk { db in
                    try db.execute(sql: """
                        UPDATE clipboard_items 
                        SET copy_count = copy_count + 1, last_copy_time = ? 
                        WHERE id = ?
                        """, arguments: [timestamp, id])
                }
            } catch {
                print("❌ 更新文件数据库复制次数失败: \(error)")
            }
        }
    }
    
    // 双更新：内存和文件数据库都更新收藏状态
    func updateFavoriteStatus(_ id: Int64, isFavorite: Bool) throws {
        // 1. 同步更新内存数据库
        try dbManager.writeToMemory { db in
            try db.execute(sql: "UPDATE clipboard_items SET is_favorite = ? WHERE id = ?", 
                          arguments: [isFavorite, id])
        }
        
        // 2. 异步更新文件数据库
        Task.detached { [weak self] in
            do {
                try await self?.dbManager.writeToDisk { db in
                    try db.execute(sql: "UPDATE clipboard_items SET is_favorite = ? WHERE id = ?", 
                                  arguments: [isFavorite, id])
                }
            } catch {
                print("❌ 更新文件数据库收藏状态失败: \(error)")
            }
        }
    }
    
    // 从内存获取数量
    func getCount() throws -> Int {
        return try dbManager.readFromMemory { db in
            try ClipboardItem.fetchCount(db)
        }
    }
    
    // 从内存获取应用列表
    func getDistinctSourceApps() throws -> [String] {
        return try dbManager.readFromMemory { db in
            try String.fetchAll(db, sql: """
                SELECT DISTINCT source_app 
                FROM clipboard_items 
                WHERE source_app IS NOT NULL AND source_app != ''
                ORDER BY source_app
                """)
        }
    }
}