import Foundation
import SQLite3

class SQLiteClipboardRepository: ClipboardRepository {
    private let dbManager = DatabaseManager.shared
    
    func save(_ item: ClipboardItem) async throws {
        let sql = """
        INSERT OR REPLACE INTO clipboard_items (
            id, content, type, timestamp, source_app, source_app_bundle_id,
            is_favorite, html_content, copy_count, first_copy_time,
            last_copy_time, image_data, image_dimensions, image_size, file_path
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            // 绑定参数
            sqlite3_bind_text(statement, 1, item.id.uuidString, -1, nil)
            sqlite3_bind_text(statement, 2, item.content, -1, nil)
            sqlite3_bind_text(statement, 3, item.type.rawValue, -1, nil)
            sqlite3_bind_int64(statement, 4, Int64(item.timestamp.timeIntervalSince1970 * 1000))
            
            if let sourceApp = item.sourceApp.isEmpty ? nil : item.sourceApp {
                sqlite3_bind_text(statement, 5, sourceApp, -1, nil)
            } else {
                sqlite3_bind_null(statement, 5)
            }
            
            if let bundleID = item.sourceAppBundleID {
                sqlite3_bind_text(statement, 6, bundleID, -1, nil)
            } else {
                sqlite3_bind_null(statement, 6)
            }
            
            sqlite3_bind_int(statement, 7, item.isFavorite ? 1 : 0)
            
            if let htmlContent = item.htmlContent {
                sqlite3_bind_text(statement, 8, htmlContent, -1, nil)
            } else {
                sqlite3_bind_null(statement, 8)
            }
            
            sqlite3_bind_int(statement, 9, Int32(item.copyCount))
            sqlite3_bind_int64(statement, 10, Int64(item.firstCopyTime.timeIntervalSince1970 * 1000))
            sqlite3_bind_int64(statement, 11, Int64(item.lastCopyTime.timeIntervalSince1970 * 1000))
            
            if let imageData = item.imageData {
                sqlite3_bind_blob(statement, 12, imageData.withUnsafeBytes { $0.baseAddress }, Int32(imageData.count), nil)
            } else {
                sqlite3_bind_null(statement, 12)
            }
            
            if let dimensions = item.imageDimensions {
                sqlite3_bind_text(statement, 13, dimensions, -1, nil)
            } else {
                sqlite3_bind_null(statement, 13)
            }
            
            if let imageSize = item.imageSize {
                sqlite3_bind_int64(statement, 14, imageSize)
            } else {
                sqlite3_bind_null(statement, 14)
            }
            
            if let filePath = item.filePath {
                sqlite3_bind_text(statement, 15, filePath, -1, nil)
            } else {
                sqlite3_bind_null(statement, 15)
            }
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
    
    func delete(_ id: UUID) async throws {
        let sql = "DELETE FROM clipboard_items WHERE id = ?"
        
        try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, id.uuidString, -1, nil)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
    
    func loadAll() async throws -> [ClipboardItem] {
        let sql = "SELECT * FROM clipboard_items ORDER BY timestamp DESC LIMIT 1000"
        return try await queryItems(sql: sql)
    }
    
    func search(query: String) async throws -> [ClipboardItem] {
        let sql = """
        SELECT * FROM clipboard_items 
        WHERE content LIKE ? OR source_app LIKE ?
        ORDER BY timestamp DESC
        """
        
        return try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            let searchPattern = "%\(query)%"
            sqlite3_bind_text(statement, 1, searchPattern, -1, nil)
            sqlite3_bind_text(statement, 2, searchPattern, -1, nil)
            
            return try self.extractItems(from: statement)
        }
    }
    
    func getByCategory(_ category: ClipboardCategory) async throws -> [ClipboardItem] {
        let sql: String
        let bindValue: String?
        
        switch category {
        case .history:
            return try await loadAll()
        case .favorites:
            sql = "SELECT * FROM clipboard_items WHERE is_favorite = 1 ORDER BY timestamp DESC"
            bindValue = nil
        case .text:
            sql = "SELECT * FROM clipboard_items WHERE type = ? ORDER BY timestamp DESC"
            bindValue = ClipboardItemType.text.rawValue
        case .images:
            sql = "SELECT * FROM clipboard_items WHERE type = ? ORDER BY timestamp DESC"
            bindValue = ClipboardItemType.image.rawValue
        case .links:
            sql = "SELECT * FROM clipboard_items WHERE type = ? ORDER BY timestamp DESC"
            bindValue = ClipboardItemType.link.rawValue
        case .files:
            sql = "SELECT * FROM clipboard_items WHERE type = ? ORDER BY timestamp DESC"
            bindValue = ClipboardItemType.file.rawValue
        case .mail:
            sql = "SELECT * FROM clipboard_items WHERE type = ? ORDER BY timestamp DESC"
            bindValue = ClipboardItemType.email.rawValue
        }
        
        return try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            if let bindValue = bindValue {
                sqlite3_bind_text(statement, 1, bindValue, -1, nil)
            }
            
            return try self.extractItems(from: statement)
        }
    }
    
    func getSortedItems(for category: ClipboardCategory, sortOption: SortOption, isReversed: Bool) async throws -> [ClipboardItem] {
        let items = try await getByCategory(category)
        
        let sortedItems: [ClipboardItem]
        switch sortOption {
        case .lastCopyTime:
            sortedItems = items.sorted { $0.lastCopyTime > $1.lastCopyTime }
        case .firstCopyTime:
            sortedItems = items.sorted { $0.firstCopyTime < $1.firstCopyTime }
        case .numberOfCopies:
            sortedItems = items.sorted { $0.copyCount > $1.copyCount }
        case .size:
            sortedItems = items.sorted { $0.content.count > $1.content.count }
        }
        
        return isReversed ? sortedItems.reversed() : sortedItems
    }
    
    func incrementCopyCount(_ id: UUID) async throws {
        let sql = """
        UPDATE clipboard_items 
        SET copy_count = copy_count + 1, last_copy_time = ? 
        WHERE id = ?
        """
        
        try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_int64(statement, 1, Int64(Date().timeIntervalSince1970 * 1000))
            sqlite3_bind_text(statement, 2, id.uuidString, -1, nil)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
    
    func updateFavoriteStatus(_ id: UUID, isFavorite: Bool) async throws {
        let sql = "UPDATE clipboard_items SET is_favorite = ? WHERE id = ?"
        
        try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_int(statement, 1, isFavorite ? 1 : 0)
            sqlite3_bind_text(statement, 2, id.uuidString, -1, nil)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
    
    func cleanupOldData(olderThan date: Date) async throws {
        let sql = """
        DELETE FROM clipboard_items 
        WHERE timestamp < ? AND is_favorite = 0
        """
        
        try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_int64(statement, 1, Int64(date.timeIntervalSince1970 * 1000))
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
    
    func getCount() async throws -> Int {
        let sql = "SELECT COUNT(*) FROM clipboard_items"
        
        return try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_step(statement) == SQLITE_ROW {
                return Int(sqlite3_column_int(statement, 0))
            }
            
            return 0
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func queryItems(sql: String) async throws -> [ClipboardItem] {
        return try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            return try self.extractItems(from: statement)
        }
    }
    
    private func extractItems(from statement: OpaquePointer?) throws -> [ClipboardItem] {
        var items: [ClipboardItem] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let item = try extractSingleItem(from: statement)
            items.append(item)
        }
        
        return items
    }
    
    private func extractSingleItem(from statement: OpaquePointer?) throws -> ClipboardItem {
        guard let statement = statement else {
            throw DatabaseError.executionFailed("Statement is nil")
        }
        
        // 获取所有列的值
        let idString = String(cString: sqlite3_column_text(statement, 0))
        let content = String(cString: sqlite3_column_text(statement, 1))
        let typeString = String(cString: sqlite3_column_text(statement, 2))
        let timestamp = sqlite3_column_int64(statement, 3)
        
        let sourceApp = sqlite3_column_type(statement, 4) == SQLITE_NULL ? 
            "Unknown" : String(cString: sqlite3_column_text(statement, 4))
            
        let sourceAppBundleID = sqlite3_column_type(statement, 5) == SQLITE_NULL ? 
            nil : String(cString: sqlite3_column_text(statement, 5))
            
        let isFavorite = sqlite3_column_int(statement, 6) == 1
        
        let htmlContent = sqlite3_column_type(statement, 7) == SQLITE_NULL ? 
            nil : String(cString: sqlite3_column_text(statement, 7))
            
        let copyCount = Int(sqlite3_column_int(statement, 8))
        let firstCopyTime = sqlite3_column_int64(statement, 9)
        let lastCopyTime = sqlite3_column_int64(statement, 10)
        
        let imageData: Data? = {
            if sqlite3_column_type(statement, 11) == SQLITE_NULL {
                return nil
            }
            let blobPointer = sqlite3_column_blob(statement, 11)
            let blobSize = sqlite3_column_bytes(statement, 11)
            return Data(bytes: blobPointer!, count: Int(blobSize))
        }()
        
        let imageDimensions = sqlite3_column_type(statement, 12) == SQLITE_NULL ? 
            nil : String(cString: sqlite3_column_text(statement, 12))
            
        let imageSize = sqlite3_column_type(statement, 13) == SQLITE_NULL ? 
            nil : sqlite3_column_int64(statement, 13)
            
        let filePath = sqlite3_column_type(statement, 14) == SQLITE_NULL ? 
            nil : String(cString: sqlite3_column_text(statement, 14))
        
        // 创建ClipboardItem
        guard let id = UUID(uuidString: idString),
              let type = ClipboardItemType(rawValue: typeString) else {
            throw DatabaseError.executionFailed("Invalid data format")
        }
        
        // 使用数据库构造函数创建ClipboardItem
        return ClipboardItem(
            id: id,
            content: content,
            type: type,
            timestamp: Date(timeIntervalSince1970: Double(timestamp) / 1000),
            sourceApp: sourceApp,
            isFavorite: isFavorite,
            htmlContent: htmlContent,
            copyCount: copyCount,
            firstCopyTime: Date(timeIntervalSince1970: Double(firstCopyTime) / 1000),
            lastCopyTime: Date(timeIntervalSince1970: Double(lastCopyTime) / 1000),
            sourceAppBundleID: sourceAppBundleID,
            imageData: imageData,
            imageDimensions: imageDimensions,
            imageSize: imageSize,
            filePath: filePath
        )
    }
}