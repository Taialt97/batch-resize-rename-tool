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

    @State private var showOverrides = false

    private var file: ImageFile? {
        viewModel.fileAt(id: fileID)
    }

    private var computedName: String {
        viewModel.outputName(for: fileID, in: batch)
    }

    var body: some View {
        if let file {
            VStack(alignment: .leading, spacing: 4) {
                mainRow(file)
                if showOverrides {
                    overrideFields(file)
                }
            }
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
                withAnimation(.easeInOut(duration: 0.2)) { showOverrides.toggle() }
            } label: {
                Image(systemName: showOverrides ? "chevron.up" : "slider.horizontal.3")
                    .foregroundStyle(.secondary)
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

    // MARK: - Override Panel

    private func overrideFields(_ file: ImageFile) -> some View {
        let b = currentBatch ?? batch

        return HStack(spacing: 10) {
            overrideField("W",
                text: file.hasWidthOverride ? file.overrideWidth
                    : inherited(batchValue: b.overrideWidth, batchFlag: b.hasWidthOverride, global: viewModel.globalWidth),
                overridden: file.hasWidthOverride, width: 60,
                onCommit: { v in viewModel.updateFile(id: fileID) { $0.hasWidthOverride = true; $0.overrideWidth = v } },
                onReset: { viewModel.resetFileOverride(id: fileID, field: .width) }
            )
            overrideField("H",
                text: file.hasHeightOverride ? file.overrideHeight
                    : inherited(batchValue: b.overrideHeight, batchFlag: b.hasHeightOverride, global: viewModel.globalHeight),
                overridden: file.hasHeightOverride, width: 60,
                onCommit: { v in viewModel.updateFile(id: fileID) { $0.hasHeightOverride = true; $0.overrideHeight = v } },
                onReset: { viewModel.resetFileOverride(id: fileID, field: .height) }
            )
            overrideField("Pad",
                text: file.hasPaddingOverride ? file.overridePadding
                    : inherited(batchValue: b.overridePadding, batchFlag: b.hasPaddingOverride, global: viewModel.globalPadding),
                overridden: file.hasPaddingOverride, width: 50,
                onCommit: { v in viewModel.updateFile(id: fileID) { $0.hasPaddingOverride = true; $0.overridePadding = v } },
                onReset: { viewModel.resetFileOverride(id: fileID, field: .padding) }
            )
            overrideField("Pattern",
                text: file.hasNamePatternOverride ? file.overrideNamePattern
                    : inherited(batchValue: b.overrideNamePattern, batchFlag: b.hasNamePatternOverride, global: viewModel.globalNamePattern),
                overridden: file.hasNamePatternOverride, width: 150,
                onCommit: { v in viewModel.updateFile(id: fileID) { $0.hasNamePatternOverride = true; $0.overrideNamePattern = v } },
                onReset: { viewModel.resetFileOverride(id: fileID, field: .namePattern) }
            )
            Spacer()
        }
        .padding(.leading, 44)
        .padding(.top, 2)
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
                    .help("Reset to batch / global setting")
                }
            }
            CommitTextField(text: text, onCommit: onCommit)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(overridden ? .primary : .secondary)
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

    // MARK: - Value Resolution

    private func inherited(
        batchValue: String, batchFlag: Bool, global: String
    ) -> String {
        (batchFlag && !batchValue.isEmpty) ? batchValue : global
    }

    private var currentBatch: Batch? {
        viewModel.batches.first { $0.id == batch.id }
    }
}
