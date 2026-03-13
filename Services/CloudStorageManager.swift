import Foundation

enum CloudFileState: Equatable {
    case local
    case uploading
    case uploaded
    case downloading(progress: Double)
    case evicted
    case unavailable
}

actor CloudStorageManager {
    static let shared = CloudStorageManager()

    private var iCloudContainerURL: URL?
    private var isICloudAvailable: Bool = false
    private var metadataQuery: NSMetadataQuery?
    private var fileStates: [String: CloudFileState] = [:]

    init() {
        Task { await setup() }
    }

    // MARK: - Setup

    private func setup() {
        checkICloudAvailability()
    }

    private func checkICloudAvailability() {
        isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        if isICloudAvailable {
            // Get the iCloud container URL on a background thread
            Task.detached { [weak self] in
                let containerURL = FileManager.default.url(
                    forUbiquityContainerIdentifier: AppConstants.iCloudContainerID
                )
                await self?.setContainerURL(containerURL)
            }
        }
    }

    private func setContainerURL(_ url: URL?) {
        iCloudContainerURL = url
        if let url = url {
            let documentsURL = url.appendingPathComponent("Documents")
            try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    var cloudAvailable: Bool {
        isICloudAvailable && iCloudContainerURL != nil
    }

    func saveToCloud(fileData: Data, fileName: String) async throws -> String {
        let destinationURL = try fileURL(for: fileName)

        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var writeError: Error?

        coordinator.coordinate(writingItemAt: destinationURL, options: .forReplacing, error: &coordinatorError) { newURL in
            do {
                try fileData.write(to: newURL)
            } catch {
                writeError = error
            }
        }

        if let error = coordinatorError ?? writeError {
            throw error
        }

        fileStates[fileName] = .uploaded
        return fileName
    }

    func fetchFromCloud(fileName: String) async throws -> Data {
        let sourceURL = try fileURL(for: fileName)

        // Check if file needs to be downloaded
        if !FileManager.default.fileExists(atPath: sourceURL.path) {
            // Attempt to start download
            try FileManager.default.startDownloadingUbiquitousItem(at: sourceURL)
            fileStates[fileName] = .downloading(progress: 0)

            // Wait for download with polling
            for _ in 0..<60 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if FileManager.default.fileExists(atPath: sourceURL.path) {
                    break
                }
            }
        }

        var coordinatorError: NSError?
        var data: Data?
        var readError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { newURL in
            do {
                data = try Data(contentsOf: newURL)
            } catch {
                readError = error
            }
        }

        if let error = coordinatorError ?? readError {
            throw error
        }

        guard let fileData = data else {
            throw CloudStorageError.fileNotFound
        }

        fileStates[fileName] = .uploaded
        return fileData
    }

    func deleteFromCloud(fileName: String) async throws {
        let fileURL = try fileURL(for: fileName)

        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var deleteError: Error?

        coordinator.coordinate(writingItemAt: fileURL, options: .forDeleting, error: &coordinatorError) { newURL in
            do {
                try FileManager.default.removeItem(at: newURL)
            } catch {
                deleteError = error
            }
        }

        if let error = coordinatorError ?? deleteError {
            throw error
        }

        fileStates[fileName] = nil
    }

    func isFileAvailable(fileName: String) -> Bool {
        guard let url = try? fileURL(for: fileName) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func fileState(for fileName: String) -> CloudFileState {
        guard cloudAvailable else { return .unavailable }
        return fileStates[fileName] ?? .local
    }

    func startDownload(fileName: String) async throws {
        let url = try fileURL(for: fileName)
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        fileStates[fileName] = .downloading(progress: 0)
    }

    // MARK: - Storage Usage

    func cloudStorageUsage() async -> (used: Int64, fileCount: Int) {
        guard let containerURL = iCloudContainerURL else { return (0, 0) }
        let documentsURL = containerURL.appendingPathComponent("Documents")

        var totalSize: Int64 = 0
        var count = 0

        if let enumerator = FileManager.default.enumerator(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resourceValues.fileSize {
                    totalSize += Int64(size)
                    count += 1
                }
            }
        }

        return (totalSize, count)
    }

    // MARK: - Local Fallback

    func saveLocally(fileData: Data, fileName: String) throws -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        try fileData.write(to: fileURL)
        fileStates[fileName] = .local
        return fileName
    }

    func fetchLocally(fileName: String) throws -> Data {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        return try Data(contentsOf: fileURL)
    }

    /// Save file data, using iCloud if available, otherwise local storage
    func save(fileData: Data, fileName: String) async throws -> String {
        if cloudAvailable {
            return try await saveToCloud(fileData: fileData, fileName: fileName)
        } else {
            return try saveLocally(fileData: fileData, fileName: fileName)
        }
    }

    // MARK: - Helpers

    private func fileURL(for fileName: String) throws -> URL {
        if let containerURL = iCloudContainerURL {
            return containerURL.appendingPathComponent("Documents").appendingPathComponent(fileName)
        }
        // Fallback to local Documents
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CloudStorageError.containerNotFound
        }
        return documentsURL.appendingPathComponent(fileName)
    }
}

enum CloudStorageError: LocalizedError {
    case containerNotFound
    case fileNotFound
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .containerNotFound: return "iCloud container not found"
        case .fileNotFound: return "File not found in cloud storage"
        case .writeFailed: return "Failed to write file to cloud storage"
        }
    }
}
