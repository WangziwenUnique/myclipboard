import Foundation
import GRDB

class GRDBDatabaseManager {
    static let shared = GRDBDatabaseManager()
    
    private var dbWriter: DatabaseWriter!
    
    private init() {
        do {
            dbWriter = try openDatabase()
            try migrator.migrate(dbWriter)
        } catch {
            fatalError("数据库初始化失败: \(error)")
        }
    }
    
    private var databaseURL: URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.clipboard.app"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID)
        
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ 无法创建应用数据目录: \(error)")
        }
        
        let dbURL = appDirectory.appendingPathComponent("clipboard.db")
        print("📁 数据库路径: \(dbURL.path)")
        return dbURL
    }
    
    private func openDatabase() throws -> DatabaseWriter {
        let dbWriter = try DatabasePool(path: databaseURL.path)
        
        // 配置数据库
        var config = Configuration()
        config.prepareDatabase { db in
            // 启用外键约束
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            // 优化性能
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
        }
        
        print("✅ GRDB数据库已打开")
        return dbWriter
    }
    
    // GRDB迁移系统 - 比手工SQL优雅多了
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // V1: 创建初始表结构（兼容现有数据）
        migrator.registerMigration("createClipboardItems") { db in
            try db.create(table: "clipboard_items", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("content", .text).notNull()
                t.column("type", .text).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("source_app", .text)
                t.column("source_app_bundle_id", .text)
                t.column("is_favorite", .integer).notNull().defaults(to: 0)
                t.column("html_content", .text)
                t.column("copy_count", .integer).notNull().defaults(to: 1)
                t.column("first_copy_time", .integer).notNull()
                t.column("last_copy_time", .integer).notNull()
                t.column("image_data", .blob)
                t.column("image_dimensions", .text)
                t.column("image_size", .integer)
                t.column("file_path", .text)
            }
        }
        
        // V2: 创建索引优化查询性能
        migrator.registerMigration("createIndexes") { db in
            try db.create(index: "idx_timestamp", on: "clipboard_items", columns: ["timestamp"], ifNotExists: true)
            try db.create(index: "idx_type", on: "clipboard_items", columns: ["type"], ifNotExists: true)
            try db.create(index: "idx_favorite", on: "clipboard_items", columns: ["is_favorite"], ifNotExists: true)
            try db.create(index: "idx_source_app", on: "clipboard_items", columns: ["source_app"], ifNotExists: true)
        }
        
        // V3: 创建FTS5全文搜索表和触发器
        migrator.registerMigration("createFTS5") { db in
            // 创建FTS5虚拟表
            try db.execute(sql: """
                CREATE VIRTUAL TABLE clipboard_items_fts USING fts5(
                    content,
                    source_app,
                    content='clipboard_items',
                    content_rowid='id'
                )
                """)
            
            // 从现有数据初始化FTS表
            try db.execute(sql: """
                INSERT INTO clipboard_items_fts(rowid, content, source_app)
                SELECT id, content, source_app FROM clipboard_items
                """)
            
            // 创建自动同步触发器
            try db.execute(sql: """
                CREATE TRIGGER clipboard_fts_insert AFTER INSERT ON clipboard_items 
                BEGIN
                    INSERT INTO clipboard_items_fts(rowid, content, source_app) 
                    VALUES (new.id, new.content, new.source_app);
                END
                """)
            
            try db.execute(sql: """
                CREATE TRIGGER clipboard_fts_update AFTER UPDATE ON clipboard_items 
                BEGIN
                    UPDATE clipboard_items_fts 
                    SET content=new.content, source_app=new.source_app 
                    WHERE rowid=new.id;
                END
                """)
            
            try db.execute(sql: """
                CREATE TRIGGER clipboard_fts_delete AFTER DELETE ON clipboard_items 
                BEGIN
                    DELETE FROM clipboard_items_fts WHERE rowid=old.id;
                END
                """)
        }
        
        return migrator
    }
    
    // 公开的数据库访问接口
    var writer: DatabaseWriter {
        return dbWriter
    }
    
    func read<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        return try await dbWriter.read(block)
    }
    
    func write<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        return try await dbWriter.write(block)
    }
}

// 自定义错误类型
enum GRDBDatabaseError: Error {
    case itemNotFound
    case invalidData
    case migrationFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .itemNotFound:
            return "数据项未找到"
        case .invalidData:
            return "数据格式无效"
        case .migrationFailed(let message):
            return "数据库迁移失败: \(message)"
        }
    }
}
