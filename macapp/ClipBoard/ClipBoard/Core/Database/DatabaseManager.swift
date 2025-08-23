import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "database.queue", qos: .userInitiated)
    
    private init() {
        openDatabase()
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    private var databaseURL: URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.clipboard.app"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID)
        
        // 确保目录存在
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ 无法创建应用数据目录: \(error)")
        }
        
        let dbURL = appDirectory.appendingPathComponent("clipboard.db")
        print("📁 数据库路径: \(dbURL.path)")
        return dbURL
    }
    
    private func openDatabase() {
        let dbPath = databaseURL.path
        
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("✅ SQLite数据库已打开: \(dbPath)")
        } else {
            print("❌ 无法打开SQLite数据库")
            if let db = db {
                print("错误: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }
    
    private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }
    
    private func createTables() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS clipboard_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            type TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            source_app TEXT,
            source_app_bundle_id TEXT,
            is_favorite INTEGER DEFAULT 0,
            html_content TEXT,
            copy_count INTEGER DEFAULT 1,
            first_copy_time INTEGER NOT NULL,
            last_copy_time INTEGER NOT NULL,
            image_data BLOB,
            image_dimensions TEXT,
            image_size INTEGER,
            file_path TEXT
        );
        """
        
        let createIndexes = [
            "CREATE INDEX IF NOT EXISTS idx_timestamp ON clipboard_items(timestamp DESC);",
            "CREATE INDEX IF NOT EXISTS idx_type ON clipboard_items(type);",
            "CREATE INDEX IF NOT EXISTS idx_favorite ON clipboard_items(is_favorite);",
            "CREATE INDEX IF NOT EXISTS idx_source_app ON clipboard_items(source_app);"
        ]
        
        dbQueue.sync {
            if sqlite3_exec(db, createTableSQL, nil, nil, nil) == SQLITE_OK {
                print("✅ 数据库表创建成功")
                
                for indexSQL in createIndexes {
                    sqlite3_exec(db, indexSQL, nil, nil, nil)
                }
                print("✅ 数据库索引创建成功")
            } else {
                print("❌ 数据库表创建失败")
                if let db = db {
                    print("错误: \(String(cString: sqlite3_errmsg(db)))")
                }
            }
        }
    }
    
    func execute<T>(_ operation: @escaping (OpaquePointer) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            dbQueue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume(throwing: DatabaseError.connectionFailed)
                    return
                }
                
                do {
                    let result = try operation(db)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func executeSync<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        return try dbQueue.sync { [weak self] in
            guard let self = self, let db = self.db else {
                throw DatabaseError.connectionFailed
            }
            return try operation(db)
        }
    }
}

enum DatabaseError: Error {
    case connectionFailed
    case preparationFailed(String)
    case executionFailed(String)
    case bindingFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .connectionFailed:
            return "数据库连接失败"
        case .preparationFailed(let message):
            return "SQL准备失败: \(message)"
        case .executionFailed(let message):
            return "SQL执行失败: \(message)"
        case .bindingFailed(let message):
            return "参数绑定失败: \(message)"
        }
    }
}