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
                withAnimation(.easeInOut(duration: 0.2)) {
                    if viewModel.editorTarget == .batch(batch.id) {
                        viewModel.editorTarget = nil
                    } else {
                        viewModel.editorTarget = .batch(batch.id)
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(viewModel.editorTarget == .batch(batch.id) ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Edit batch overrides")

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
