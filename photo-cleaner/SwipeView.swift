import SwiftUI
import Photos
import UIKit

struct SwipeView: View {
    @ObservedObject var viewModel: PhotoViewModel

    @State private var dragOffset: CGSize = .zero
    @State private var topImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width
            let cardHeight = min(geo.size.height, cardWidth * 1.35) // responsive height

            ZStack {
                if viewModel.hasMoreCards {
                    // Next card preview
                    if let next = nextAsset {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.secondary.opacity(0.12))
                            .overlay {
                                Text("Next")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: cardWidth, height: cardHeight) // <-- constrain
                            .scaleEffect(0.97)
                            .offset(y: 10)

                        // (Optional) You can render next thumbnail too; kept minimal for memory.
//                        _ = next
                    }

                    // Top card
                    if let asset = currentAsset {
                        CardView(asset: asset, image: topImage, dragOffset: dragOffset)
                            .frame(width: cardWidth, height: cardHeight) // <-- constrain
                            .offset(dragOffset)
                            .rotationEffect(.degrees(Double(dragOffset.width / 18)))
//                            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
                            .gesture(dragGesture(for: asset, in: geo.size))
                            .task(id: asset.localIdentifier) {
                                topImage = nil
                                let px = min(1400, max(800, cardWidth * UIScreen.main.scale))
                                let target = CGSize(width: px, height: px)
                                topImage = await viewModel.thumbnail(for: asset, targetSize: target)
                            }
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: dragOffset)
                    }
                } else {
                    VStack(spacing: 10) {
                        Text("No more screenshots.")
                            .font(.title3.weight(.semibold))
                        Text("Swipe more after taking screenshots, or adjust your fetch logic later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // .frame(height: 520)  <-- remove fixed height
    }

    private var currentAsset: PHAsset? {
        guard viewModel.currentIndex < viewModel.assets.count else { return nil }
        return viewModel.assets[viewModel.currentIndex]
    }

    private var nextAsset: PHAsset? {
        let idx = viewModel.currentIndex + 1
        guard idx < viewModel.assets.count else { return nil }
        return viewModel.assets[idx]
    }

    private func dragGesture(for asset: PHAsset, in size: CGSize) -> some Gesture {
        let threshold = size.width * 0.25

        return DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let x = value.translation.width

                if x <= -threshold {
                    // swipe left => queue for deletion
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                        dragOffset = CGSize(width: -size.width * 1.2, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        viewModel.swipeLeftDelete(asset)
                        dragOffset = .zero
                    }
                } else if x >= threshold {
                    // swipe right => keep
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                        dragOffset = CGSize(width: size.width * 1.2, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        viewModel.swipeRightKeep(asset)
                        dragOffset = .zero
                    }
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        dragOffset = .zero
                    }
                }
            }
    }
}
