import SwiftUI
import Photos
import UIKit

struct DeletionQueueView: View {
    @ObservedObject var viewModel: PhotoViewModel

    // ровно 3 колонки
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
                    ForEach(viewModel.deletionQueue, id: \.localIdentifier) { asset in
                        DeletionQueueCell(asset: asset, viewModel: viewModel)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("To Delete")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.deletionQueue.count) selected")
                    .font(.headline)
                Text("Space: \(viewModel.spaceToBeFreedFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.cleanTrash() }
            } label: {
                Label("Clean", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.deletionQueue.isEmpty || viewModel.isCleaning)
        }
    }
}

private struct DeletionQueueCell: View {
    let asset: PHAsset
    @ObservedObject var viewModel: PhotoViewModel

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.secondary.opacity(0.12)) // фон на весь блок

            if let image {
                // Важно: aspectFit, чтобы всегда корректно отображалось при любом соотношении сторон.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .topTrailing) { // крестик относительно ВСЕГО блока
            Button {
                viewModel.unqueueFromDeletion(asset)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .aspectRatio(1, contentMode: .fit)
        .task(id: asset.localIdentifier) {
            image = nil
            let scale = UIScreen.main.scale
            let target = CGSize(width: 320 * scale, height: 320 * scale)
            // Для aspectFit отображения — просим PhotoKit отдать thumbnail под aspectFit.
            image = await viewModel.thumbnail(for: asset, targetSize: target, contentMode: .aspectFit)
        }
    }
}
