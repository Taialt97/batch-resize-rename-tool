import SwiftUI

/// Buffers keystrokes into local @State. The ViewModel is only mutated on
/// focus‑loss or Enter, and only when the text actually changed. No @Binding
/// dependency chain, so SwiftUI dependency tracking stops at this view.
struct CommitTextField: View {
    let text: String
    let onCommit: (String) -> Void

    @State private var localText = ""
    @State private var baseline = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $localText)
            .focused($isFocused)
            .transaction { $0.animation = nil }
            .onAppear {
                localText = text
                baseline = text
            }
            .onChange(of: text) { newValue in
                if !isFocused {
                    localText = newValue
                    baseline = newValue
                }
            }
            .onChange(of: isFocused) { focused in
                if !focused && localText != baseline {
                    onCommit(localText)
                    baseline = localText
                }
            }
            .onSubmit {
                if localText != baseline {
                    onCommit(localText)
                    baseline = localText
                }
            }
    }
}

struct BatchFileRowView: View {
    let fileID: UUID
    let batch: Batch
    @ObservedObject var viewModel: BatchProcessorViewModel

    private var isEditing: Bool {
        viewModel.editorTarget == .file(fileID, batchID: batch.id)
    }

    private var file: ImageFile? {
        viewModel.fileAt(id: fileID)
    }

    private var computedName: String {
        viewModel.outputName(for: fileID, in: batch)
    }

    var body: some View {
        if let file {
            mainRow(file)
        }
    }

    // MARK: - Main Row

    private func mainRow(_ file: ImageFile) -> some View {
        HStack(spacing: 8) {
            thumbnailView(file)

            statusIndicators

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(outputFileName)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if hasAnyOverride(file) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 4) {
                    Text("\u{2190}")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                    Text(file.originalName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("(\(file.pixelWidth)\u{00D7}\(file.pixelHeight))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isEditing {
                        viewModel.editorTarget = nil
                    } else {
                        viewModel.editorTarget = .file(fileID, batchID: batch.id)
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(isEditing ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Edit per‑file overrides")

            Button {
                viewModel.removeFileFromBatch(fileID: fileID, batchID: batch.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove from batch")
        }
    }

    // MARK: - Status Indicators

    private var outputFileName: String {
        let crop = viewModel.cropSource(for: fileID, in: batch)
        let ext = crop != .none ? "png" : (file?.originalURL.pathExtension ?? "png")
        return "\(computedName).\(ext)"
    }

    private var statusIndicators: some View {
        VStack(spacing: 2) {
            sourceIndicator(
                symbol: "textformat",
                source: viewModel.renameSource(for: fileID, in: batch),
                activeLabel: "Rename",
                noneLabel: "No rename pattern"
            )
            sourceIndicator(
                symbol: "crop",
                source: viewModel.cropSource(for: fileID, in: batch),
                activeLabel: "Resize",
                noneLabel: "No crop dimensions"
            )
        }
    }

    private func sourceIndicator(
        symbol: String,
        source: BatchProcessorViewModel.SettingSource,
        activeLabel: String,
        noneLabel: String
    ) -> some View {
        let helpText: String
        switch source {
        case .global: helpText = "\(activeLabel): Global"
        case .batch:  helpText = "\(activeLabel): Batch override"
        case .file:   helpText = "\(activeLabel): File override"
        case .none:   helpText = noneLabel
        }

        return Image(systemName: symbol)
            .font(.system(size: 9))
            .foregroundStyle(indicatorColor(source))
            .opacity(source == .none ? 0.35 : 1.0)
            .frame(width: 14, height: 12)
            .help(helpText)
    }

    private func indicatorColor(_ source: BatchProcessorViewModel.SettingSource) -> Color {
        switch source {
        case .global: return .green
        case .batch:  return .orange
        case .file:   return .blue
        case .none:   return .gray
        }
    }

    // MARK: - Helpers

    private func hasAnyOverride(_ file: ImageFile) -> Bool {
        file.hasWidthOverride || file.hasHeightOverride
            || file.hasPaddingOverride || file.hasNamePatternOverride
    }

    private func thumbnailView(_ file: ImageFile) -> some View {
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
