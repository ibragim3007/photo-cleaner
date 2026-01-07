import Foundation
import Photos
import SwiftUI
import UIKit
import Combine

@MainActor
final class PhotoViewModel: ObservableObject {
    @Published private(set) var authorization: PhotoAuthorizationState = .notDetermined

    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var currentIndex: Int = 0

    @Published private(set) var deletionQueue: [PHAsset] = []
    @Published private(set) var deletionQueueBytes: Int64 = 0

    @Published var isCleaning: Bool = false
    @Published private(set) var isLoading: Bool = false

    private let manager: PhotoManager

    init(manager: PhotoManager = .shared) {
        self.manager = manager
        self.authorization = manager.currentAuthorization()
    }

    var spaceToBeFreedFormatted: String {
        ByteCountFormatter.string(fromByteCount: deletionQueueBytes, countStyle: .file)
    }

    var hasMoreCards: Bool {
        currentIndex < assets.count
    }

    func onAppear() async {
        authorization = manager.currentAuthorization()
        if authorization == .notDetermined {
            authorization = await manager.requestAuthorization()
        }
        await loadIfNeeded()
    }

    func loadIfNeeded() async {
        guard authorization == .authorized || authorization == .limited else { return }
        guard assets.isEmpty, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        // Screenshots only (initial MVP scope).
        assets = manager.fetchScreenshots(limit: 300)
        currentIndex = 0
    }

    func thumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await manager.requestThumbnail(for: asset, targetSize: targetSize)
    }

    func swipeLeftDelete(_ asset: PHAsset) {
        guard !deletionQueue.contains(where: { $0.localIdentifier == asset.localIdentifier }) else {
            advance()
            return
        }
        deletionQueue.append(asset)
        deletionQueueBytes += manager.estimatedFileSizeBytes(for: asset)
        advance()
    }

    func swipeRightKeep(_ asset: PHAsset) {
        advance()
    }

    private func advance() {
        currentIndex = min(currentIndex + 1, assets.count)
    }

    func cleanTrash() async {
        guard !deletionQueue.isEmpty, !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }

        do {
            // IMPORTANT: batch delete => one system confirmation.
            try await manager.delete(assets: deletionQueue)
            deletionQueue.removeAll()
            deletionQueueBytes = 0

            // Simple refresh so deleted items don't reappear in the feed.
            assets.removeAll()
            currentIndex = 0
            await loadIfNeeded()
        } catch {
            // MVP: keep it silent-ish; you can surface an alert later.
            // print("Delete failed:", error)
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
