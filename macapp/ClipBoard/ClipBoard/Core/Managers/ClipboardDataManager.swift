import Foundation
import CryptoKit

class ClipboardDataManager {
    private let documentsURL: URL
    private let dataFileName = "clipboard_data.json"
    private let encryptionKey: SymmetricKey
    
    init() {
        // 获取用户文档目录
        self.documentsURL = FileManager.default.urls(for: .documentDirectory, 
                                                     in: .userDomainMask).first!
        
        // 生成或加载加密密钥
        self.encryptionKey = Self.getOrCreateEncryptionKey()
        
        // 确保数据目录存在
        createDataDirectoryIfNeeded()
    }
    
    private var dataFileURL: URL {
        return documentsURL.appendingPathComponent(dataFileName)
    }
    
    // MARK: - Directory Management
    
    private func createDataDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: documentsURL.path) {
            try? fileManager.createDirectory(at: documentsURL, 
                                           withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Encryption Key Management
    
    private static func getOrCreateEncryptionKey() -> SymmetricKey {
        let keychain = Keychain()
        let keyIdentifier = "com.myclipboard.encryption.key"
        
        if let existingKeyData = keychain.getData(keyIdentifier) {
            return SymmetricKey(data: existingKeyData)
        } else {
            // 生成新的加密密钥
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            keychain.setData(keyData, forKey: keyIdentifier)
            return newKey
        }
    }
    
    // MARK: - Data Loading
    
    func loadItems() throws -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            return [] // 文件不存在时返回空数组
        }
        
        let encryptedData = try Data(contentsOf: dataFileURL)
        
        if encryptedData.isEmpty {
            return []
        }
        
        // 解密数据
        let decryptedData = try decrypt(encryptedData)
        
        // 解析JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([ClipboardItem].self, from: decryptedData)
    }
    
    // MARK: - Data Saving
    
    func saveItems(_ items: [ClipboardItem]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(items)
        
        // 加密数据
        let encryptedData = try encrypt(jsonData)
        
        // 异步写入文件
        try encryptedData.write(to: dataFileURL, options: .atomic)
        
        print("已保存 \(items.count) 个剪贴板项目到: \(dataFileURL.path)")
    }
    
    // MARK: - Encryption/Decryption
    
    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }
    
    private func decrypt(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
    
    // MARK: - File Management
    
    func getDataFileSize() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: dataFileURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func clearAllData() throws {
        if FileManager.default.fileExists(atPath: dataFileURL.path) {
            try FileManager.default.removeItem(at: dataFileURL)
        }
    }
    
    // 导出数据（用于备份）
    func exportData() throws -> URL {
        let exportURL = documentsURL.appendingPathComponent("clipboard_export_\(Date().timeIntervalSince1970).json")
        
        // 导出未加密的JSON格式数据
        let items = try loadItems()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(items)
        try jsonData.write(to: exportURL)
        
        return exportURL
    }
}

// MARK: - Simple Keychain Helper

private class Keychain {
    func setData(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 先删除现有项目
        SecItemDelete(query as CFDictionary)
        
        // 添加新项目
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getData(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        
        return nil
    }
}