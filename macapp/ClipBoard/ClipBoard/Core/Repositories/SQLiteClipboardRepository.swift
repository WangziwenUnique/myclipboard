import Foundation
import SQLite3

class SQLiteClipboardRepository: ClipboardRepository {
    private let dbManager = DatabaseManager.shared
    
    func save(_ item: ClipboardItem) async throws -> ClipboardItem {
        // 简化的数据验证
        guard !item.content.isEmpty else {
            throw DatabaseError.bindingFailed("Invalid content: empty")
        }
        
        guard ClipboardItemType.allCases.contains(item.type) else {
            throw DatabaseError.bindingFailed("Invalid type: \(item.type.rawValue)")
        }
        
        let sql: String
        if item.id == 0 {
            // 新项目，让数据库自动生成ID
            sql = """
            INSERT INTO clipboard_items (
                content, type, timestamp, source_app, source_app_bundle_id,
                is_favorite, html_content, copy_count, first_copy_time,
                last_copy_time, image_data, image_dimensions, image_size, file_path
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        } else {
            // 更新现有项目
            sql = """
            INSERT OR REPLACE INTO clipboard_items (
                id, content, type, timestamp, source_app, source_app_bundle_id,
                is_favorite, html_content, copy_count, first_copy_time,
                last_copy_time, image_data, image_dimensions, image_size, file_path
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        }
        
        return try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            // 根据是否为新项目绑定不同参数
            var paramIndex: Int32 = 1
            
            // 如果是更新现有项目，先绑定ID
            if item.id != 0 {
                sqlite3_bind_int64(statement, paramIndex, item.id)
                paramIndex += 1
            }
            
            // 绑定其他参数
            sqlite3_bind_text(statement, paramIndex, item.content, -1, nil)
            sqlite3_bind_text(statement, paramIndex + 1, item.type.rawValue, -1, nil)
            sqlite3_bind_int64(statement, paramIndex + 2, Int64(item.timestamp.timeIntervalSince1970 * 1000))
            
            sqlite3_bind_text(statement, paramIndex + 3, item.sourceApp, -1, nil)
            
            if let bundleID = item.sourceAppBundleID, !bundleID.isEmpty {
                sqlite3_bind_text(statement, paramIndex + 4, bundleID, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex + 4)
            }
            
            sqlite3_bind_int(statement, paramIndex + 5, item.isFavorite ? 1 : 0)
            
            if let htmlContent = item.htmlContent, !htmlContent.isEmpty {
                sqlite3_bind_text(statement, paramIndex + 6, htmlContent, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex + 6)
            }
            
            sqlite3_bind_int(statement, paramIndex + 7, Int32(item.copyCount))
            sqlite3_bind_int64(statement, paramIndex + 8, Int64(item.firstCopyTime.timeIntervalSince1970 * 1000))
            sqlite3_bind_int64(statement, paramIndex + 9, Int64(item.lastCopyTime.timeIntervalSince1970 * 1000))
            
            if let imageData = item.imageData {
                sqlite3_bind_blob(statement, paramIndex + 10, imageData.withUnsafeBytes { $0.baseAddress }, Int32(imageData.count), nil)
            } else {
                sqlite3_bind_null(statement, paramIndex + 10)
            }
            
            if let dimensions = item.imageDimensions, !dimensions.isEmpty {
                sqlite3_bind_text(statement, paramIndex + 11, dimensions, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex + 11)
            }
            
            if let imageSize = item.imageSize, imageSize > 0 {
                sqlite3_bind_int64(statement, paramIndex + 12, imageSize)
            } else {
                sqlite3_bind_null(statement, paramIndex + 12)
            }
            
            if let filePath = item.filePath, !filePath.isEmpty {
                sqlite3_bind_text(statement, paramIndex + 13, filePath, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex + 13)
            }
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            // 获取生成的ID或使用原有ID
            let finalID: Int64
            if item.id == 0 {
                finalID = sqlite3_last_insert_rowid(db)
            } else {
                finalID = item.id
            }
            
            // 返回带有正确ID的ClipboardItem
            return ClipboardItem(
                id: finalID,
                content: item.content,
                type: item.type,
                timestamp: item.timestamp,
                sourceApp: item.sourceApp,
                isFavorite: item.isFavorite,
                htmlContent: item.htmlContent,
                copyCount: item.copyCount,
                firstCopyTime: item.firstCopyTime,
                lastCopyTime: item.lastCopyTime,
                sourceAppBundleID: item.sourceAppBundleID,
                imageData: item.imageData,
                imageDimensions: item.imageDimensions,
                imageSize: item.imageSize,
                filePath: item.filePath
            )
        }
    }
    
    func delete(_ id: Int64) async throws {
        let sql = "DELETE FROM clipboard_items WHERE id = ?"
        
        try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_int64(statement, 1, id)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
    
    func loadAll() async throws -> [ClipboardItem] {
        let sql = "SELECT * FROM clipboard_items ORDER BY timestamp DESC LIMIT 1000"
        return try await queryItems(sql: sql)
    }
    
    func loadPage(page: Int, limit: Int) async throws -> [ClipboardItem] {
        let offset = page * limit
        let sql = "SELECT * FROM clipboard_items ORDER BY timestamp DESC LIMIT \(limit) OFFSET \(offset)"
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
    
    func incrementCopyCount(_ id: Int64) async throws {
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
            sqlite3_bind_int64(statement, 2, id)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
    
    func updateFavoriteStatus(_ id: Int64, isFavorite: Bool) async throws {
        let sql = "UPDATE clipboard_items SET is_favorite = ? WHERE id = ?"
        
        try await dbManager.execute { db in
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.preparationFailed(String(cString: sqlite3_errmsg(db)))
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_int(statement, 1, isFavorite ? 1 : 0)
            sqlite3_bind_int64(statement, 2, id)
            
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
        
        // 获取ID（现在是整数）
        let id = sqlite3_column_int64(statement, 0)
        
        guard let contentPtr = sqlite3_column_text(statement, 1) else {
            throw DatabaseError.executionFailed("Content column is null")
        }
        let content = String(cString: contentPtr)
        
        guard let typePtr = sqlite3_column_text(statement, 2) else {
            throw DatabaseError.executionFailed("Type column is null")
        }
        let typeString = String(cString: typePtr)
        
        let timestamp = sqlite3_column_int64(statement, 3)
        
        let sourceApp = sqlite3_column_type(statement, 4) == SQLITE_NULL ? 
            "" : String(cString: sqlite3_column_text(statement, 4))
            
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
        guard let type = ClipboardItemType(rawValue: typeString) else {
            throw DatabaseError.executionFailed("Invalid type format: '\(typeString)'. Valid types: \(ClipboardItemType.allCases.map { $0.rawValue })")
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