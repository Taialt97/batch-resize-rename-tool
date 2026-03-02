import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = BatchProcessorViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            GlobalSettingsPanel(viewModel: viewModel)
                .padding()

            Divider()

            toolbar

            Divider()

            if viewModel.allFiles.isEmpty {
                emptyState
            } else {
                FileListView(viewModel: viewModel)
            }

            Divider()

            bottomBar
                .padding()
        }
        .frame(minWidth: 900, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $viewModel.showNoCropConfirmation) {
            NoCropConfirmationSheet(viewModel: viewModel)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drag & Drop Images Here")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("or")
                .foregroundStyle(.tertiary)
            Button {
                viewModel.importViaPanel()
            } label: {
                Label("Search / Add Files", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Text("PNG · JPEG · TIFF · BMP · GIF · HEIC")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary.opacity(0.4))
        )
        .padding()
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.importViaPanel()
            } label: {
                Label("Add Files", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Divider().frame(height: 20)

            Button {
                viewModel.createBatchFromSelected()
            } label: {
                Label("Create Batch", systemImage: "rectangle.stack.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasSelectedUngrouped)
            .help("Group selected ungrouped files into a new batch")

            Spacer()

            Text("\(viewModel.allFiles.count) file(s) imported")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                viewModel.removeAllFiles()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 16) {
            if viewModel.isProcessing {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)
                Text("\(Int(viewModel.progress * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            } else {
                if viewModel.totalBatchedFiles > 0 {
                    Text("\(viewModel.totalBatchedFiles) file(s) in \(viewModel.batches.filter { !$0.fileIDs.isEmpty }.count) batch(es)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button(action: viewModel.commitChanges) {
                Label("Commit Changes", systemImage: "checkmark.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isProcessing || viewModel.totalBatchedFiles == 0)
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier, options: nil
            ) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true)
                else { return }
                DispatchQueue.main.async { viewModel.addFiles(urls: [url]) }
            }
        }
    }
}

// MARK: - No-Crop Confirmation Sheet

private struct NoCropConfirmationSheet: View {
    @ObservedObject var viewModel: BatchProcessorViewModel
    @State private var dontShowAgain = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crop")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("No Global Cropping Values")
                .font(.headline)

            Text("Some files have no cropping dimensions set at any level.\nThey will be renamed and copied without resizing.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Toggle("Don't show again", isOn: $dontShowAgain)
                .toggleStyle(.checkbox)

            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.showNoCropConfirmation = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Continue") {
                    if dontShowAgain { viewModel.suppressNoCropWarning = true }
                    viewModel.confirmAndCommit()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 400)
    }
}
