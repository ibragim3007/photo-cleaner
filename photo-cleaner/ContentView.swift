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
                    // Keep previews stable (avoid PhotoKit calls / permission prompts).
                    VStack(spacing: 12) {
                        Text("Preview Mode")
                            .font(.title3.weight(.semibold))
                        Text("PhotoKit is disabled in Xcode Previews.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview {
    ContentView()
}
