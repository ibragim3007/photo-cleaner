//
//  ContentView.swift
//  photo-cleaner
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PhotoViewModel()

    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isRunningInPreviews {
                    PreviewSwipeStack(urls: PhotoManager.previewMockImageURLs)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                } else {
                    switch viewModel.authorization {
                    case .notDetermined:
                        ProgressView("Requesting Photo Library access…")

                    case .denied, .restricted:
                        UnauthorizedView(openSettings: viewModel.openSettings)

                    case .authorized, .limited:
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Space to be freed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(viewModel.spaceToBeFreedFormatted)
                                        .font(.title3.weight(.semibold))
                                }
                                Spacer()
                                Button {
                                    Task { await viewModel.cleanTrash() }
                                } label: {
                                    Label("Clean Trash", systemImage: "trash")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.deletionQueue.isEmpty || viewModel.isCleaning)
                            }
                            .padding(.horizontal)

                            SwipeView(viewModel: viewModel)
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
            .navigationTitle("Photo Cleaner")
            .task {
                guard !isRunningInPreviews else { return }
                await viewModel.onAppear()
            }
        }
    }
}

// MARK: - Unauthorized

private struct UnauthorizedView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Photo access is required to clean screenshots.")
                .multilineTextAlignment(.center)

            Button("Open Settings", action: openSettings)
                .buttonStyle(.borderedProminent)

            Text("Tip: You can grant Limited access and select screenshots.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview swipe stack (no PhotoKit)

private struct PreviewSwipeStack: View {
    let urls: [URL]

    @State private var index: Int = 0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width
            let cardHeight = min(geo.size.height, cardWidth * 1.35)

            ZStack {
                if index < urls.count {
                    if index + 1 < urls.count {
                        PreviewRemoteCard(url: urls[index + 1], dragOffset: .zero)
                            .frame(width: cardWidth, height: cardHeight) // <-- constrain
                            .scaleEffect(0.97)
                            .offset(y: 10)
                    }

                    PreviewRemoteCard(url: urls[index], dragOffset: dragOffset)
                        .frame(width: cardWidth, height: cardHeight) // <-- constrain
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width / 18)))
                        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
                        .gesture(dragGesture(in: geo.size))
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: dragOffset)
                } else {
                    VStack(spacing: 10) {
                        Text("Preview: done")
                            .font(.title3.weight(.semibold))
                        Text("Все мок-картинки просмотрены.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // .frame(height: 520) <-- remove fixed height
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        let threshold = size.width * 0.25

        return DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let x = value.translation.width
                if x <= -threshold {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                        dragOffset = CGSize(width: -size.width * 1.2, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        index += 1
                        dragOffset = .zero
                    }
                } else if x >= threshold {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                        dragOffset = CGSize(width: size.width * 1.2, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        index += 1
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

private struct PreviewRemoteCard: View {
    let url: URL
    let dragOffset: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.92))

            AsyncImage(url: url, transaction: Transaction(animation: .spring(response: 0.28, dampingFraction: 0.85))) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit() // <-- was scaledToFill
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                        Text("Failed to load")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            overlayBadge
                .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var overlayBadge: some View {
        let x = dragOffset.width
        let opacity = min(1.0, abs(x) / 90.0)

        return Group {
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

#Preview {
    ContentView()
}
