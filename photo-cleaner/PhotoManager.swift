import Foundation
import Photos
import UIKit

enum PhotoAuthorizationState: Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case limited

    static func from(_ status: PHAuthorizationStatus) -> PhotoAuthorizationState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        case .limited: return .limited
        @unknown default: return .denied
        }
    }
}

final class PhotoManager {
    static let shared = PhotoManager()

    // Preview mocks (internet URLs)
    static let previewMockImageURLs: [URL] = [
        URL(string: "https://i.postimg.cc/QxqdyP0n/Chat-GPT-Image-17-2025-10-52-28.png")!,
        URL(string: "https://i.postimg.cc/sDDbQjnS/IMG-4148-2.jpg")!,
        URL(string: "https://i.postimg.cc/MTCsW9Mm/Chat-GPT-Image-10-2025-14-53-31.png")!,
        URL(string: "https://i.postimg.cc/8kLM0GJJ/Chat-GPT-Image-10-2025-19-27-37.png")!
    ]

    private let imageManager = PHCachingImageManager()
    private init() {}

    // MARK: Authorization

    func currentAuthorization() -> PhotoAuthorizationState {
        PhotoAuthorizationState.from(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAuthorization() async -> PhotoAuthorizationState {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return PhotoAuthorizationState.from(status)
    }

    // MARK: Fetching (Screenshots)

    func fetchScreenshots(limit: Int = 250) -> [PHAsset] {
        let options = PHFetchOptions()

        // Filter: only screenshots
        let screenshotBit = PHAssetMediaSubtype.photoScreenshot.rawValue
        options.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", screenshotBit)

        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        let result = PHAsset.fetchAssets(with: .image, options: options)

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    // MARK: Thumbnails

    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFit // <-- was .aspectFill
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            // High quality reduces (but does not eliminate) multi-callback behavior.
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            let lock = NSLock()
            var didResume = false
            var bestSoFar: UIImage? = nil

            // Fallback: if PhotoKit only gives us a degraded image, don't hang forever.
            let fallbackDelay: TimeInterval = 0.25
            DispatchQueue.main.asyncAfter(deadline: .now() + fallbackDelay) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: bestSoFar)
            }

            _ = self.imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let error = info?[PHImageErrorKey] as? NSError

                lock.lock()
                defer { lock.unlock() }

                guard !didResume else { return }

                if isCancelled || error != nil {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                if let image {
                    bestSoFar = image
                    // Prefer the final (non-degraded) result.
                    if !isDegraded {
                        didResume = true
                        continuation.resume(returning: image)
                        return
                    }
                }
                // If it's degraded, wait for the final callback; fallback timer handles "final never arrives".
            }
        }
    }

    // Convenience for grids (fills the cell nicely)
    func requestGridThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await requestThumbnail(for: asset, targetSize: targetSize, contentMode: .aspectFill)
    }

    // MARK: Size (for "Space to be freed")

    func estimatedFileSizeBytes(for asset: PHAsset) -> Int64 {
        // MVP: Uses KVC "fileSize" on PHAssetResource (not public API).
        // If you want a fully-supported approach, you must stream data via PHAssetResourceManager (more expensive).
        let resources = PHAssetResource.assetResources(for: asset)
        let sum = resources.reduce(into: Int64(0)) { acc, res in
            if let n = res.value(forKey: "fileSize") as? CLong {
                acc += Int64(n)
            } else if let n = res.value(forKey: "fileSize") as? Int64 {
                acc += n
            }
        }
        return sum
    }

    // MARK: Batch Deletion

    /// Deletes all queued assets in ONE transaction so the system confirmation popup appears only once.
    func delete(assets: [PHAsset]) async throws {
        guard !assets.isEmpty else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                } else {
                    let err = NSError(domain: "PhotoCleaner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Delete failed"]) 
                    continuation.resume(throwing: err)
                }
            })
        }
    }
  
    // MARK: Preview helpers (not used by PhotoKit flow)
    func fetchRemotePreviewImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    /// Utility: targetSize (px) for a 3-column square grid cell.
    func gridTargetSizePx(containerWidthPoints: CGFloat, horizontalPaddingPoints: CGFloat = 16, spacingPoints: CGFloat = 10) -> CGSize {
        let columns: CGFloat = 3
        let totalSpacing = spacingPoints * (columns - 1)
        let available = max(0, containerWidthPoints - (horizontalPaddingPoints * 2) - totalSpacing)
        let cellPoints = floor(available / columns)
        let px = cellPoints * UIScreen.main.scale
        return CGSize(width: px, height: px)
    }
}
