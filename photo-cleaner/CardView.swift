import SwiftUI
import Photos
import UIKit

struct CardView: View {
    let asset: PHAsset
    let image: UIImage?
    let dragOffset: CGSize

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.92)) // <-- better for aspectFit letterboxing

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit() // <-- was scaledToFill (cropped / could look "wrong")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topLeading) {
            overlayBadge
                .padding(14)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityLabel(Text("Screenshot"))
    }

    private var overlayBadge: some View {
        let x = dragOffset.width
        let opacity = min(1.0, abs(x) / 90.0)

        return HStack(spacing: 10) {
            if x < -10 {
                Label("TRASH", systemImage: "trash.fill")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .opacity(opacity)
            } else if x > 10 {
                Label("KEEP", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .opacity(opacity)
            }
        }
    }
}
