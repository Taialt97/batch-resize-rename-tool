import SwiftUI

struct GlobalSettingsPanel: View {
    @ObservedObject var viewModel: BatchProcessorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global Settings")
                .font(.headline)

            HStack(spacing: 24) {
                canvasFields
                Divider().frame(height: 44)
                namingFields
            }

            Text("Bracket syntax: [00] → \(viewModel.sequenceStartsAtZero ? "00, 01" : "01, 02") …  [0000] → \(viewModel.sequenceStartsAtZero ? "0000, 0001" : "0001, 0002") …  Zero count sets digit width.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Canvas Size + Padding

    private var canvasFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Canvas")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                labeledField("W:", text: $viewModel.globalWidth, width: 70)
                labeledField("H:", text: $viewModel.globalHeight, width: 70)
                labeledField("Pad:", text: $viewModel.globalPadding, width: 50)
                Text("px")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Name Pattern + Toggle

    private var namingFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Naming")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Pattern:")
                    .foregroundStyle(.secondary)
                TextField("e.g. Hero_[000]_icon", text: $viewModel.globalNamePattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)

                Toggle("Number across all batches", isOn: $viewModel.continuousNumbering)
                    .toggleStyle(.checkbox)
                    .help("ON = one running sequence across all batches. OFF = each batch starts at 1.")

                Toggle("Start at 0", isOn: $viewModel.sequenceStartsAtZero)
                    .toggleStyle(.checkbox)
                    .help("First file uses 0 instead of 1 in [00] patterns.")
            }
        }
    }

    // MARK: - Helpers

    private func labeledField(
        _ label: String, text: Binding<String>, width: CGFloat
    ) -> some View {
        HStack(spacing: 3) {
            Text(label).foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
        }
    }
}
