import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: BatchProcessorViewModel

    var body: some View {
        List {
            // --- Ungrouped import pool ---
            if !viewModel.ungroupedFiles.isEmpty {
                Section {
                    ForEach(viewModel.ungroupedFiles) { file in
                        ungroupedRow(file)
                    }
                } header: {
                    ungroupedHeader
                }
            }

            // --- Draggable & collapsible batches ---
            if !viewModel.batches.isEmpty {
                Section {
                    ForEach(viewModel.batches) { batch in
                        batchSection(batch)
                    }
                    .onMove { viewModel.moveBatches(from: $0, to: $1) }
                } header: {
                    Text("Batches (\(viewModel.batches.count))")
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Batch Section

    @ViewBuilder
    private func batchSection(_ batch: Batch) -> some View {
        DisclosureGroup(
            isExpanded: viewModel.isExpandedBinding(for: batch.id)
        ) {
            batchSettingsRow(batch)

            ForEach(batch.fileIDs, id: \.self) { fileID in
                BatchFileRowView(
                    fileID: fileID,
                    batch: batch,
                    viewModel: viewModel
                )
            }
            .onMove { viewModel.moveFilesInBatch(batchID: batch.id, from: $0, to: $1) }
        } label: {
            batchLabel(batch)
        }
    }

    // MARK: - Ungrouped Header

    private var ungroupedHeader: some View {
        HStack {
            Text("Ungrouped Files (\(viewModel.ungroupedFiles.count))")

            Spacer()

            Button("Select All") { viewModel.selectAllUngrouped() }
                .buttonStyle(.borderless)
                .font(.caption)

            if !viewModel.selectedFileIDs.isEmpty {
                Button("Deselect") { viewModel.deselectAll() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
    }

    // MARK: - Ungrouped Row

    private func ungroupedRow(_ file: ImageFile) -> some View {
        let isSelected = viewModel.selectedFileIDs.contains(file.id)

        return HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .font(.body)

            thumbnailImage(file)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.originalName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(file.pixelWidth) × \(file.pixelHeight) px")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { viewModel.removeFile(id: file.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.toggleSelection(file.id) }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.08) : nil)
    }

    // MARK: - Batch Label

    private func batchLabel(_ batch: Batch) -> some View {
        HStack {
            Image(systemName: "rectangle.stack.fill")
                .foregroundStyle(Color.accentColor)
            Text(batch.label)
                .fontWeight(.semibold)
            Text("· \(batch.fileIDs.count) file(s)")
                .foregroundStyle(.secondary)

            Spacer()

            if viewModel.hasSelectedUngrouped {
                Button("+ Add Selected") {
                    viewModel.addSelectedToBatch(batchID: batch.id)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Button {
                viewModel.removeBatch(id: batch.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Delete batch (files return to ungrouped)")
        }
    }

    // MARK: - Batch Settings Row (Tier 2)

    private func batchSettingsRow(_ batch: Batch) -> some View {
        HStack(spacing: 10) {
            Text("Batch Override:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)

            batchOverrideField(
                "W", batchID: batch.id,
                value: \.overrideWidth, flag: \.hasWidthOverride,
                fallback: viewModel.globalWidth, width: 60
            )
            batchOverrideField(
                "H", batchID: batch.id,
                value: \.overrideHeight, flag: \.hasHeightOverride,
                fallback: viewModel.globalHeight, width: 60
            )
            batchOverrideField(
                "Pad", batchID: batch.id,
                value: \.overridePadding, flag: \.hasPaddingOverride,
                fallback: viewModel.globalPadding, width: 50
            )
            batchOverrideField(
                "Pattern", batchID: batch.id,
                value: \.overrideNamePattern, flag: \.hasNamePatternOverride,
                fallback: viewModel.globalNamePattern, width: 140
            )

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func batchOverrideField(
        _ label: String,
        batchID: UUID,
        value valuePath: WritableKeyPath<Batch, String>,
        flag flagPath: WritableKeyPath<Batch, Bool>,
        fallback: String,
        width: CGFloat
    ) -> some View {
        let batch = viewModel.batches.first { $0.id == batchID }
        let isOverridden = batch?[keyPath: flagPath] ?? false
        let currentText = isOverridden ? (batch?[keyPath: valuePath] ?? "") : fallback
        let field = viewModel.overrideFieldFor(valuePath)

        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if isOverridden {
                    Button {
                        if let f = field { viewModel.resetBatchOverride(batchID: batchID, field: f) }
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .help("Reset to global setting")
                }
            }
            CommitTextField(text: currentText, onCommit: { newValue in
                guard let idx = viewModel.batches.firstIndex(where: { $0.id == batchID })
                else { return }
                viewModel.batches[idx][keyPath: flagPath] = true
                viewModel.batches[idx][keyPath: valuePath] = newValue
            })
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(isOverridden ? .primary : .secondary)
        }
    }

    // MARK: - Thumbnail

    private func thumbnailImage(_ file: ImageFile) -> some View {
        Group {
            if let thumb = file.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
            } else {
                Image(systemName: "photo")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
        }
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
