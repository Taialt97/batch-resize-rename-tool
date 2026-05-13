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

            if viewModel.editorTarget != nil {
                Divider()
                OverrideEditorPanel(viewModel: viewModel)
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

            Text("Some files have no cropping dimensions set at any level.\nThey will be renamed and copied without resizing.\n\nYou'll choose a destination folder, and a \"Converted Images\" folder will be created with the processed files inside.")
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

// MARK: - Override Editor Panel

private struct OverrideEditorPanel: View {
    @ObservedObject var viewModel: BatchProcessorViewModel

    var body: some View {
        HStack(spacing: 10) {
            panelContent
            Spacer()
            Button { viewModel.editorTarget = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close editor")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .id(viewModel.editorTarget)
    }

    @ViewBuilder
    private var panelContent: some View {
        if case .batch(let batchID) = viewModel.editorTarget,
           let batch = viewModel.batches.first(where: { $0.id == batchID }) {
            Label(batch.label, systemImage: "rectangle.stack.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)

            overrideField("W",
                text: batch.hasWidthOverride ? batch.overrideWidth : viewModel.globalWidth,
                overridden: batch.hasWidthOverride, width: 60,
                onCommit: { v in setBatch(batchID, flag: \.hasWidthOverride, value: \.overrideWidth, v) },
                onReset: { viewModel.resetBatchOverride(batchID: batchID, field: .width) })
            overrideField("H",
                text: batch.hasHeightOverride ? batch.overrideHeight : viewModel.globalHeight,
                overridden: batch.hasHeightOverride, width: 60,
                onCommit: { v in setBatch(batchID, flag: \.hasHeightOverride, value: \.overrideHeight, v) },
                onReset: { viewModel.resetBatchOverride(batchID: batchID, field: .height) })
            overrideField("Pad",
                text: batch.hasPaddingOverride ? batch.overridePadding : viewModel.globalPadding,
                overridden: batch.hasPaddingOverride, width: 50,
                onCommit: { v in setBatch(batchID, flag: \.hasPaddingOverride, value: \.overridePadding, v) },
                onReset: { viewModel.resetBatchOverride(batchID: batchID, field: .padding) })
            overrideField("Pattern",
                text: batch.hasNamePatternOverride ? batch.overrideNamePattern : viewModel.globalNamePattern,
                overridden: batch.hasNamePatternOverride, width: 150,
                onCommit: { v in setBatch(batchID, flag: \.hasNamePatternOverride, value: \.overrideNamePattern, v) },
                onReset: { viewModel.resetBatchOverride(batchID: batchID, field: .namePattern) })

        } else if case .file(let fileID, batchID: let batchID) = viewModel.editorTarget,
                  let file = viewModel.fileAt(id: fileID),
                  let batch = viewModel.batches.first(where: { $0.id == batchID }) {
            Label(file.originalName, systemImage: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)
                .lineLimit(1)

            overrideField("W",
                text: file.hasWidthOverride ? file.overrideWidth
                    : inherited(batch.overrideWidth, flag: batch.hasWidthOverride, global: viewModel.globalWidth),
                overridden: file.hasWidthOverride, width: 60,
                onCommit: { v in viewModel.updateFile(id: fileID) { $0.hasWidthOverride = true; $0.overrideWidth = v } },
                onReset: { viewModel.resetFileOverride(id: fileID, field: .width) })
            overrideField("H",
                text: file.hasHeightOverride ? file.overrideHeight
                    : inherited(batch.overrideHeight, flag: batch.hasHeightOverride, global: viewModel.globalHeight),
                overridden: file.hasHeightOverride, width: 60,
                onCommit: { v in viewModel.updateFile(id: fileID) { $0.hasHeightOverride = true; $0.overrideHeight = v } },
                onReset: { viewModel.resetFileOverride(id: fileID, field: .height) })
            overrideField("Pad",
                text: file.hasPaddingOverride ? file.overridePadding
                    : inherited(batch.overridePadding, flag: batch.hasPaddingOverride, global: viewModel.globalPadding),
                overridden: file.hasPaddingOverride, width: 50,
                onCommit: { v in viewModel.updateFile(id: fileID) { $0.hasPaddingOverride = true; $0.overridePadding = v } },
                onReset: { viewModel.resetFileOverride(id: fileID, field: .padding) })
            overrideField("Pattern",
                text: file.hasNamePatternOverride ? file.overrideNamePattern
                    : inherited(batch.overrideNamePattern, flag: batch.hasNamePatternOverride, global: viewModel.globalNamePattern),
                overridden: file.hasNamePatternOverride, width: 150,
                onCommit: { v in viewModel.updateFile(id: fileID) { $0.hasNamePatternOverride = true; $0.overrideNamePattern = v } },
                onReset: { viewModel.resetFileOverride(id: fileID, field: .namePattern) })
        }
    }

    private func setBatch(_ batchID: UUID, flag: WritableKeyPath<Batch, Bool>, value: WritableKeyPath<Batch, String>, _ v: String) {
        guard let idx = viewModel.batches.firstIndex(where: { $0.id == batchID }) else { return }
        viewModel.batches[idx][keyPath: flag] = true
        viewModel.batches[idx][keyPath: value] = v
    }

    private func inherited(_ batchValue: String, flag: Bool, global: String) -> String {
        (flag && !batchValue.isEmpty) ? batchValue : global
    }

    @ViewBuilder
    private func overrideField(
        _ label: String,
        text: String,
        overridden: Bool,
        width: CGFloat,
        onCommit: @escaping (String) -> Void,
        onReset: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if overridden {
                    Button(action: onReset) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .help("Reset to inherited setting")
                }
            }
            CommitTextField(text: text, onCommit: onCommit)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(overridden ? .primary : .secondary)
        }
    }
}
