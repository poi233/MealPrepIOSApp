//
//  RecipeImageCacheManager.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/27/25.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Cached Image Metadata

struct CachedImageMetadata: Codable {
    let url: String
    let fileName: String
    let fileSize: Int64
    let lastAccessed: Date
    let createdAt: Date
    let expiresAt: Date
    let contentType: String?

    init(url: String, fileName: String, fileSize: Int64, contentType: String? = nil) {
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.lastAccessed = Date()
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days
        self.contentType = contentType
    }

    func withUpdatedAccess() -> CachedImageMetadata {
        return CachedImageMetadata(
            url: url,
            fileName: fileName,
            fileSize: fileSize,
            lastAccessed: Date(),
            createdAt: createdAt,
            expiresAt: expiresAt,
            contentType: contentType
        )
    }

    private init(url: String, fileName: String, fileSize: Int64, lastAccessed: Date, createdAt: Date, expiresAt: Date, contentType: String?) {
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.lastAccessed = lastAccessed
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.contentType = contentType
    }

    var isExpired: Bool {
        return Date() > expiresAt
    }
}

// MARK: - Image Cache Error Types

enum ImageCacheError: LocalizedError {
    case downloadFailed(Error)
    case invalidImageData
    case diskWriteFailed(Error)
    case cacheFull
    case invalidURL
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let error):
            return "Failed to download image: \(error.localizedDescription)"
        case .invalidImageData:
            return "Downloaded data is not a valid image"
        case .diskWriteFailed(let error):
            return "Failed to write image to disk: \(error.localizedDescription)"
        case .cacheFull:
            return "Image cache is full and cleanup failed"
        case .invalidURL:
            return "Invalid image URL provided"
        case .networkUnavailable:
            return "Network is not available for image download"
        }
    }
}

// MARK: - Recipe Image Cache Manager

@MainActor
class RecipeImageCacheManager: ObservableObject {
    static let shared = RecipeImageCacheManager()

    // MARK: - Configuration
    private let maxDiskCacheSize: Int64 = 200 * 1024 * 1024 // 200MB per user
    private let maxMemoryCacheSize = 50 * 1024 * 1024 // 50MB memory cache
    private let defaultCacheExpiration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let cacheCleanupThreshold: Double = 0.9 // Clean when 90% full

    // MARK: - Storage
    private let userScopedStorage = UserScopedStorageManager.shared
    private let fileManager = FileManager.default
    private var memoryCache = NSCache<NSString, UIImage>()

    // MARK: - Threading
    private let downloadQueue = DispatchQueue(label: "com.mealprep.imageCache.download", qos: .utility, attributes: .concurrent)
    private let ioQueue = DispatchQueue(label: "com.mealprep.imageCache.io", qos: .utility)
    private let cacheMetadataQueue = DispatchQueue(label: "com.mealprep.imageCache.metadata", qos: .utility)

    // MARK: - Cache Keys
    private let cacheMetadataKey = "image_cache_metadata"
    private let cacheDirName = "RecipeImageCache"

    // MARK: - Active Downloads
    private var activeDownloads: [String: Task<UIImage?, Error>] = [:]
    private let activeDownloadsLock = NSLock()

    private init() {
        setupMemoryCache()
        setupCacheDirectory()

        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        // Schedule periodic cleanup
        schedulePeriodicCleanup()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupMemoryCache() {
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100 // Max 100 images in memory
    }

    private func setupCacheDirectory() {
        ioQueue.async {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let cacheDir = documentsDir.appendingPathComponent("UserScopedStorage").appendingPathComponent(self.cacheDirName)

            if !self.fileManager.fileExists(atPath: cacheDir.path) {
                try? self.fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
                print("📁 [ImageCache] Created cache directory: \(cacheDir.path)")
            }
        }
    }

    // MARK: - Public Interface

    /// Get cached image or download if not cached
    func getCachedImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            print("❌ [ImageCache] Invalid URL: \(urlString)")
            return nil
        }

        let cacheKey = generateCacheKey(for: urlString)

        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            print("🎯 [ImageCache] Memory cache hit for: \(urlString)")
            await updateImageAccessTime(for: urlString)
            return cachedImage
        }

        // Check disk cache
        if let diskImage = await loadImageFromDisk(cacheKey: cacheKey, url: urlString) {
            print("💾 [ImageCache] Disk cache hit for: \(urlString)")

            // Add to memory cache
            let imageSize = estimateImageSize(diskImage)
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString, cost: imageSize)

            await updateImageAccessTime(for: urlString)
            return diskImage
        }

        // Download image
        return await downloadAndCacheImage(from: url)
    }

    /// Preload image into cache without returning it
    func preloadImage(from urlString: String) async {
        _ = await getCachedImage(from: urlString)
    }

    /// Clear all cached images for current user
    func clearCache() async {
        print("🧹 [ImageCache] Clearing all cached images")

        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        await clearDiskCache()

        // Clear metadata
        userScopedStorage.removeFileSystemValue(forKey: cacheMetadataKey)

        print("✅ [ImageCache] Cache cleared successfully")
    }

    /// Get cache statistics
    func getCacheStatistics() async -> ImageCacheStatistics {
        return await withCheckedContinuation { continuation in
            cacheMetadataQueue.async {
                let metadata = self.loadCacheMetadata()
                let totalSize = metadata.values.reduce(0) { $0 + $1.fileSize }
                let imageCount = metadata.count
                let diskUsagePercentage = Double(totalSize) / Double(self.maxDiskCacheSize)

                let stats = ImageCacheStatistics(
                    totalImages: imageCount,
                    totalDiskSize: totalSize,
                    maxDiskSize: self.maxDiskCacheSize,
                    diskUsagePercentage: diskUsagePercentage,
                    memoryImageCount: self.memoryCache.totalCostLimit
                )

                continuation.resume(returning: stats)
            }
        }
    }

    /// Remove specific image from cache
    func removeImageFromCache(urlString: String) async {
        let cacheKey = generateCacheKey(for: urlString)

        // Remove from memory cache
        memoryCache.removeObject(forKey: cacheKey as NSString)

        // Remove from disk cache
        await removeImageFromDisk(cacheKey: cacheKey, url: urlString)

        print("🗑️ [ImageCache] Removed image from cache: \(urlString)")
    }

    // MARK: - Private Implementation

    private func downloadAndCacheImage(from url: URL) async -> UIImage? {
        let urlString = url.absoluteString

        // Check if download is already in progress
        activeDownloadsLock.lock()
        if let existingTask = activeDownloads[urlString] {
            activeDownloadsLock.unlock()
            print("⏳ [ImageCache] Download already in progress for: \(urlString)")
            return try? await existingTask.value
        }

        // Create new download task
        let downloadTask = Task<UIImage?, Error> {
            return try await performImageDownload(from: url)
        }

        activeDownloads[urlString] = downloadTask
        activeDownloadsLock.unlock()

        do {
            let image = try await downloadTask.value

            // Clean up active downloads
            activeDownloadsLock.lock()
            activeDownloads.removeValue(forKey: urlString)
            activeDownloadsLock.unlock()

            return image
        } catch {
            print("❌ [ImageCache] Download failed for \(urlString): \(error)")

            // Clean up active downloads
            activeDownloadsLock.lock()
            activeDownloads.removeValue(forKey: urlString)
            activeDownloadsLock.unlock()

            return nil
        }
    }

    private func performImageDownload(from url: URL) async throws -> UIImage? {
        // Check network connectivity
        guard await isNetworkAvailable() else {
            throw ImageCacheError.networkUnavailable
        }

        print("📥 [ImageCache] Starting download for: \(url.absoluteString)")

        // Perform download
        let (data, response) = try await URLSession.shared.data(from: url)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ImageCacheError.downloadFailed(URLError(.badServerResponse))
        }

        // Create image from data
        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }

        print("✅ [ImageCache] Downloaded image successfully: \(url.absoluteString)")

        // Cache the image
        await cacheImage(image, data: data, for: url.absoluteString, contentType: httpResponse.mimeType)

        return image
    }

    private func cacheImage(_ image: UIImage, data: Data, for urlString: String, contentType: String?) async {
        let cacheKey = generateCacheKey(for: urlString)

        // Add to memory cache
        let imageSize = estimateImageSize(image)
        memoryCache.setObject(image, forKey: cacheKey as NSString, cost: imageSize)

        // Save to disk
        await saveImageToDisk(data: data, cacheKey: cacheKey, url: urlString, contentType: contentType)
    }

    private func saveImageToDisk(data: Data, cacheKey: String, url: String, contentType: String?) async {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                do {
                    let cacheDir = self.getCacheDirectory()
                    let fileName = "\(cacheKey).jpg"
                    let fileURL = cacheDir.appendingPathComponent(fileName)

                    // Check if we need to clean cache before writing
                    let currentCacheSize = self.getCurrentCacheSize()
                    let newTotalSize = currentCacheSize + Int64(data.count)

                    if newTotalSize > Int64(Double(self.maxDiskCacheSize) * self.cacheCleanupThreshold) {
                        print("🧹 [ImageCache] Cache size threshold reached, cleaning up...")
                        self.performCacheCleanup()
                    }

                    // Write file
                    try data.write(to: fileURL)

                    // Update metadata
                    let metadata = CachedImageMetadata(
                        url: url,
                        fileName: fileName,
                        fileSize: Int64(data.count),
                        contentType: contentType
                    )

                    self.updateCacheMetadata(for: url, metadata: metadata)

                    print("💾 [ImageCache] Saved image to disk: \(fileName)")
                    continuation.resume()

                } catch {
                    print("❌ [ImageCache] Failed to save image to disk: \(error)")
                    continuation.resume()
                }
            }
        }
    }

    private func loadImageFromDisk(cacheKey: String, url: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            ioQueue.async {
                let metadata = self.loadCacheMetadata()

                guard let imageMetadata = metadata[url],
                      !imageMetadata.isExpired else {
                    print("💔 [ImageCache] Image expired or not found in metadata: \(url)")
                    continuation.resume(returning: nil)
                    return
                }

                let cacheDir = self.getCacheDirectory()
                let fileURL = cacheDir.appendingPathComponent(imageMetadata.fileName)

                guard self.fileManager.fileExists(atPath: fileURL.path),
                      let data = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: data) else {
                    print("💔 [ImageCache] Failed to load image from disk: \(fileURL.path)")
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func removeImageFromDisk(cacheKey: String, url: String) async {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                var metadata = self.loadCacheMetadata()

                if let imageMetadata = metadata[url] {
                    let cacheDir = self.getCacheDirectory()
                    let fileURL = cacheDir.appendingPathComponent(imageMetadata.fileName)

                    // Remove file
                    try? self.fileManager.removeItem(at: fileURL)

                    // Remove from metadata
                    metadata.removeValue(forKey: url)
                    self.saveCacheMetadata(metadata)
                }

                continuation.resume()
            }
        }
    }

    private func clearDiskCache() async {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                let cacheDir = self.getCacheDirectory()

                do {
                    let files = try self.fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
                    for file in files {
                        try self.fileManager.removeItem(at: file)
                    }
                    print("🗑️ [ImageCache] Cleared disk cache directory")
                } catch {
                    print("❌ [ImageCache] Failed to clear disk cache: \(error)")
                }

                continuation.resume()
            }
        }
    }

    // MARK: - Cache Management

    private func performCacheCleanup() {
        let metadata = loadCacheMetadata()
        let sortedMetadata = metadata.values.sorted { $0.lastAccessed < $1.lastAccessed }

        var currentSize = getCurrentCacheSize()
        let targetSize = Int64(Double(maxDiskCacheSize) * 0.7) // Clean to 70% capacity

        var updatedMetadata = metadata

        for imageMetadata in sortedMetadata {
            guard currentSize > targetSize else { break }

            // Remove file
            let cacheDir = getCacheDirectory()
            let fileURL = cacheDir.appendingPathComponent(imageMetadata.fileName)

            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
                currentSize -= imageMetadata.fileSize

                // Remove from metadata
                updatedMetadata.removeValue(forKey: imageMetadata.url)

                // Remove from memory cache
                let cacheKey = generateCacheKey(for: imageMetadata.url)
                memoryCache.removeObject(forKey: cacheKey as NSString)

                print("🗑️ [ImageCache] Cleaned up: \(imageMetadata.fileName)")
            }
        }

        saveCacheMetadata(updatedMetadata)
        print("✅ [ImageCache] Cache cleanup completed. Size reduced from \(formatBytes(getCurrentCacheSize())) to \(formatBytes(currentSize))")
    }

    private func updateImageAccessTime(for url: String) async {
        await withCheckedContinuation { continuation in
            cacheMetadataQueue.async {
                var metadata = self.loadCacheMetadata()

                if let imageMetadata = metadata[url] {
                    metadata[url] = imageMetadata.withUpdatedAccess()
                    self.saveCacheMetadata(metadata)
                }

                continuation.resume()
            }
        }
    }

    // MARK: - Metadata Management

    private func loadCacheMetadata() -> [String: CachedImageMetadata] {
        return userScopedStorage.getFileSystemValue(forKey: cacheMetadataKey, type: [String: CachedImageMetadata].self) ?? [:]
    }

    private func saveCacheMetadata(_ metadata: [String: CachedImageMetadata]) {
        try? userScopedStorage.setFileSystemValue(metadata, forKey: cacheMetadataKey)
    }

    private func updateCacheMetadata(for url: String, metadata: CachedImageMetadata) {
        cacheMetadataQueue.async {
            var allMetadata = self.loadCacheMetadata()
            allMetadata[url] = metadata
            self.saveCacheMetadata(allMetadata)
        }
    }

    // MARK: - Utility Methods

    private func generateCacheKey(for url: String) -> String {
        return url.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "") ?? UUID().uuidString
    }

    private func getCacheDirectory() -> URL {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("UserScopedStorage").appendingPathComponent(cacheDirName)
    }

    private func getCurrentCacheSize() -> Int64 {
        let metadata = loadCacheMetadata()
        return metadata.values.reduce(0) { $0 + $1.fileSize }
    }

    private func estimateImageSize(_ image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return width * height * 4 // 4 bytes per pixel for RGBA
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func isNetworkAvailable() async -> Bool {
        // Simple network check - could be enhanced with Reachability
        guard let url = URL(string: "https://www.google.com") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Memory Management

    @objc private func handleMemoryWarning() {
        print("⚠️ [ImageCache] Memory warning received, clearing memory cache")
        memoryCache.removeAllObjects()
    }

    private func schedulePeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task {
                await self.performExpiredImageCleanup()
            }
        }
    }

    private func performExpiredImageCleanup() async {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                let metadata = self.loadCacheMetadata()
                var updatedMetadata = metadata
                let cacheDir = self.getCacheDirectory()

                for (url, imageMetadata) in metadata {
                    if imageMetadata.isExpired {
                        // Remove file
                        let fileURL = cacheDir.appendingPathComponent(imageMetadata.fileName)
                        try? self.fileManager.removeItem(at: fileURL)

                        // Remove from metadata
                        updatedMetadata.removeValue(forKey: url)

                        // Remove from memory cache
                        let cacheKey = self.generateCacheKey(for: url)
                        self.memoryCache.removeObject(forKey: cacheKey as NSString)

                        print("🗑️ [ImageCache] Cleaned up expired image: \(imageMetadata.fileName)")
                    }
                }

                if updatedMetadata.count != metadata.count {
                    self.saveCacheMetadata(updatedMetadata)
                    print("✅ [ImageCache] Expired image cleanup completed")
                }

                continuation.resume()
            }
        }
    }
}

// MARK: - Cache Statistics

struct ImageCacheStatistics {
    let totalImages: Int
    let totalDiskSize: Int64
    let maxDiskSize: Int64
    let diskUsagePercentage: Double
    let memoryImageCount: Int

    var formattedDiskSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalDiskSize)
    }

    var formattedMaxSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: maxDiskSize)
    }
}