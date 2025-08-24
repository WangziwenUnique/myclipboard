import Foundation
import GRDB

class GRDBDatabaseManager {
    static let shared = GRDBDatabaseManager()
    
    private var memoryDB: DatabaseQueue!
    private var diskDB: DatabaseQueue!
    
    private init() {
        do {
            // 初始化内存数据库
            memoryDB = try DatabaseQueue()
            try memoryMigrator.migrate(memoryDB)
            
            // 初始化文件数据库
            diskDB = try openDiskDatabase()
            try diskMigrator.migrate(diskDB)
            
            // 异步加载数据到内存
            Task {
                await loadDataToMemory()
            }
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
    
    private func openDiskDatabase() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue(path: databaseURL.path)
        
        print("✅ 文件数据库已打开: \(databaseURL.path)")
        return dbQueue
    }
    
    // 加载文件数据库数据到内存
    private func loadDataToMemory() async {
        do {
            let items = try await diskDB.read { db in
                try ClipboardItem
                    .order(ClipboardItem.Columns.timestamp.desc)
                    .limit(1000)
                    .fetchAll(db)
            }
            
            // 批量插入到内存数据库
            try await memoryDB.write { db in
                for item in items {
                    var mutableItem = item
                    try mutableItem.insert(db)
                }
            }
            
            print("✅ 已加载 \(items.count) 条数据到内存数据库")
        } catch {
            print("❌ 加载数据到内存失败: \(error)")
        }
    }
    
    // 内存数据库迁移
    private var memoryMigrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createClipboardItems") { db in
            try db.create(table: "clipboard_items") { t in
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
        
        return migrator
    }
    
    // 文件数据库迁移 - 保持完整结构和索引
    private var diskMigrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
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
        
        migrator.registerMigration("createIndexes") { db in
            try db.create(index: "idx_timestamp", on: "clipboard_items", columns: ["timestamp"], ifNotExists: true)
            try db.create(index: "idx_type", on: "clipboard_items", columns: ["type"], ifNotExists: true)
            try db.create(index: "idx_favorite", on: "clipboard_items", columns: ["is_favorite"], ifNotExists: true)
            try db.create(index: "idx_source_app", on: "clipboard_items", columns: ["source_app"], ifNotExists: true)
        }
        
        return migrator
    }
    
    // 内存数据库访问 - 同步操作，快速响应
    func readFromMemory<T>(_ block: @escaping (Database) throws -> T) throws -> T {
        return try memoryDB.read(block)
    }
    
    func writeToMemory<T>(_ block: @escaping (Database) throws -> T) throws -> T {
        return try memoryDB.write(block)
    }
    
    // 文件数据库访问 - 异步操作，持久化
    func readFromDisk<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        return try await diskDB.read(block)
    }
    
    func writeToDisk<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        return try await diskDB.write(block)
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
