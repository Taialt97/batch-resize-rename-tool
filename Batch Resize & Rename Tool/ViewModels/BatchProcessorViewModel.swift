import SwiftUI
import UniformTypeIdentifiers

enum DimensionUnit: String, CaseIterable {
    case pixels = "pixels"
    case percent = "percent"
    case inches = "inches"
    case cm = "cm"
    case mm = "mm"
    case points = "points"

    var needsResolution: Bool {
        switch self {
        case .inches, .cm, .mm, .points: return true
        case .pixels, .percent: return false
        }
    }
}

enum ResolutionUnit: String, CaseIterable {
    case pixelsPerInch = "pixels/inch"
    case pixelsPerCm = "pixels/cm"
}

@MainActor
final class BatchProcessorViewModel: ObservableObject {

    // MARK: - Global Settings

    @Published var globalWidth = ""
    @Published var globalHeight = ""
    @Published var globalPadding = "0"
    @Published var globalNamePattern = ""
    @Published var continuousNumbering = false
    @Published var sequenceStartsAtZero = false
    @Published var dimensionUnit: DimensionUnit = .pixels
    @Published var resolution: String = "72"
    @Published var resolutionUnit: ResolutionUnit = .pixelsPerInch

    // MARK: - Data

    @Published var allFiles: [ImageFile] = [] {
        didSet { _filesByID = Dictionary(uniqueKeysWithValues: allFiles.enumerated().map { ($1.id, $0) }) }
    }
    @Published var batches: [Batch] = []
    @Published var selectedFileIDs: Set<UUID> = []

    private var _filesByID: [UUID: Int] = [:]

    func fileAt(id: UUID) -> ImageFile? {
        guard let idx = _filesByID[id], allFiles.indices.contains(idx) else { return nil }
        return allFiles[idx]
    }

    // MARK: - Processing State

    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var showNoCropConfirmation = false

    enum EditorTarget: Hashable {
        case batch(UUID)
        case file(UUID, batchID: UUID)
    }
    @Published var editorTarget: EditorTarget?

    var suppressNoCropWarning: Bool {
        get { UserDefaults.standard.bool(forKey: "suppressNoCropWarning") }
        set { UserDefaults.standard.set(newValue, forKey: "suppressNoCropWarning") }
    }

    private var batchCounter = 0

    // MARK: - Computed Properties

    var globalWidthInt: Int? {
        guard let v = Int(globalWidth), v > 0 else { return nil }
        return v
    }
    var globalHeightInt: Int? {
        guard let v = Int(globalHeight), v > 0 else { return nil }
        return v
    }
    var globalPaddingInt: Int { max(Int(globalPadding) ?? 0, 0) }

    private var batchedFileIDs: Set<UUID> {
        Set(batches.flatMap(\.fileIDs))
    }

    var ungroupedFiles: [ImageFile] {
        let batched = batchedFileIDs
        return allFiles.filter { !batched.contains($0.id) }
    }

    var selectedUngroupedIDs: [UUID] {
        let batched = batchedFileIDs
        return allFiles.compactMap {
            (selectedFileIDs.contains($0.id) && !batched.contains($0.id)) ? $0.id : nil
        }
    }

    var hasSelectedUngrouped: Bool { !selectedUngroupedIDs.isEmpty }

    var totalBatchedFiles: Int { batches.reduce(0) { $0 + $1.fileIDs.count } }

    // MARK: - Naming Engine

    /// Replaces a `[000…]` token in `pattern` with a zero‑padded `sequenceNumber`.
    /// The count of zeros inside the brackets determines the digit width.
    private static let bracketRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\[0+\\]")
    }()

    static func applyPattern(_ pattern: String, sequenceNumber: Int) -> String {
        guard !pattern.isEmpty,
              let regex = bracketRegex,
              let match = regex.firstMatch(
                  in: pattern, range: NSRange(pattern.startIndex..., in: pattern)),
              let matchRange = Range(match.range, in: pattern)
        else { return pattern }

        let digitCount = pattern[matchRange].dropFirst().dropLast().count
        let formatted = String(format: "%0\(digitCount)d", sequenceNumber)
        var result = pattern
        result.replaceSubrange(matchRange, with: formatted)
        return result
    }

    func sequenceNumber(for fileID: UUID, in batch: Batch) -> Int {
        let offset = sequenceStartsAtZero ? 0 : 1
        if continuousNumbering {
            var count = -1
            for b in batches {
                for fid in b.fileIDs {
                    count += 1
                    if fid == fileID { return count + offset }
                }
            }
            return 0
        } else {
            guard let index = batch.fileIDs.firstIndex(of: fileID) else { return 0 }
            return index + offset
        }
    }

    func outputName(for fileID: UUID, in batch: Batch) -> String {
        guard let file = fileAt(id: fileID) else { return "unknown" }

        let pattern: String
        if file.hasNamePatternOverride && !file.overrideNamePattern.isEmpty {
            pattern = file.overrideNamePattern                     // Tier 3
        } else if batch.hasNamePatternOverride && !batch.overrideNamePattern.isEmpty {
            pattern = batch.overrideNamePattern                    // Tier 2
        } else {
            pattern = globalNamePattern                            // Tier 1
        }

        guard !pattern.isEmpty else { return file.originalName }

        let seqNum = sequenceNumber(for: fileID, in: batch)
        return Self.applyPattern(pattern, sequenceNumber: seqNum)
    }

    // MARK: - Unit Conversion

    private func effectiveDPI() -> Double {
        let res = Double(resolution) ?? 72.0
        return resolutionUnit == .pixelsPerInch ? res : res * 2.54
    }

    func toPixels(_ valueStr: String, originalPixels: Int) -> Int? {
        guard let value = Double(valueStr), value > 0 else { return nil }
        switch dimensionUnit {
        case .pixels:
            return Int(value)
        case .percent:
            return originalPixels > 0 ? max(1, Int((Double(originalPixels) * value / 100.0).rounded())) : nil
        case .inches:
            return max(1, Int((value * effectiveDPI()).rounded()))
        case .cm:
            return max(1, Int((value * effectiveDPI() / 2.54).rounded()))
        case .mm:
            return max(1, Int((value * effectiveDPI() / 25.4).rounded()))
        case .points:
            return max(1, Int((value * effectiveDPI() / 72.0).rounded()))
        }
    }

    // MARK: - Effective Dimensions (3‑Tier Resolution)

    func effectiveWidth(for fileID: UUID, in batch: Batch) -> Int? {
        let origW = fileAt(id: fileID)?.pixelWidth ?? 0
        if let file = fileAt(id: fileID), file.hasWidthOverride {
            return toPixels(file.overrideWidth, originalPixels: origW)
        }
        if batch.hasWidthOverride { return toPixels(batch.overrideWidth, originalPixels: origW) }
        return toPixels(globalWidth, originalPixels: origW)
    }

    func effectiveHeight(for fileID: UUID, in batch: Batch) -> Int? {
        let origH = fileAt(id: fileID)?.pixelHeight ?? 0
        if let file = fileAt(id: fileID), file.hasHeightOverride {
            return toPixels(file.overrideHeight, originalPixels: origH)
        }
        if batch.hasHeightOverride { return toPixels(batch.overrideHeight, originalPixels: origH) }
        return toPixels(globalHeight, originalPixels: origH)
    }

    func effectivePadding(for fileID: UUID, in batch: Batch) -> Int {
        if let file = fileAt(id: fileID),
           file.hasPaddingOverride, let p = Int(file.overridePadding), p >= 0 { return p }
        if batch.hasPaddingOverride, let p = Int(batch.overridePadding), p >= 0 { return p }
        return globalPaddingInt
    }

    // MARK: - Status Indicators

    enum SettingSource {
        case none, global, batch, file
    }

    func renameSource(for fileID: UUID, in batch: Batch) -> SettingSource {
        if let file = fileAt(id: fileID),
           file.hasNamePatternOverride, !file.overrideNamePattern.isEmpty { return .file }
        if batch.hasNamePatternOverride, !batch.overrideNamePattern.isEmpty { return .batch }
        if !globalNamePattern.isEmpty { return .global }
        return .none
    }

    func cropSource(for fileID: UUID, in batch: Batch) -> SettingSource {
        let w = effectiveWidth(for: fileID, in: batch)
        let h = effectiveHeight(for: fileID, in: batch)
        guard w != nil, h != nil else { return .none }

        if let file = fileAt(id: fileID),
           file.hasWidthOverride || file.hasHeightOverride { return .file }
        if batch.hasWidthOverride || batch.hasHeightOverride { return .batch }
        return .global
    }

    // MARK: - File Management

    func addFiles(urls: [URL]) {
        let imageExts: Set<String> = [
            "png", "jpg", "jpeg", "tiff", "tif", "bmp", "gif", "heic", "webp",
        ]
        var existing = Set(allFiles.map(\.originalURL))
        for url in urls {
            guard imageExts.contains(url.pathExtension.lowercased()),
                  !existing.contains(url) else { continue }
            allFiles.append(ImageFile(url: url))
            existing.insert(url)
        }
    }

    func addFilesAsBatch(urls: [URL]) {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "tiff", "tif", "bmp", "gif", "heic", "webp"]
        var existing = Set(allFiles.map(\.originalURL))
        var newIDs: [UUID] = []
        for url in urls {
            guard imageExts.contains(url.pathExtension.lowercased()),
                  !existing.contains(url) else { continue }
            let file = ImageFile(url: url)
            allFiles.append(file)
            existing.insert(url)
            newIDs.append(file.id)
        }
        guard !newIDs.isEmpty else { return }
        batchCounter += 1
        batches.append(Batch(label: "Batch \(batchCounter)", fileIDs: newIDs))
    }

    func importViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "Select image files to import"
        guard panel.runModal() == .OK else { return }
        addFiles(urls: panel.urls)
    }

    func removeFile(id: UUID) {
        if case .file(let fid, _) = editorTarget, fid == id { editorTarget = nil }
        for i in batches.indices { batches[i].fileIDs.removeAll { $0 == id } }
        allFiles.removeAll { $0.id == id }
        selectedFileIDs.remove(id)
    }

    func removeAllFiles() {
        editorTarget = nil
        allFiles.removeAll()
        batches.removeAll()
        selectedFileIDs.removeAll()
        batchCounter = 0
    }

    // MARK: - Selection

    func toggleSelection(_ id: UUID) {
        if selectedFileIDs.contains(id) {
            selectedFileIDs.remove(id)
        } else {
            selectedFileIDs.insert(id)
        }
    }

    func selectAllUngrouped() {
        for file in ungroupedFiles { selectedFileIDs.insert(file.id) }
    }

    func deselectAll() { selectedFileIDs.removeAll() }

    // MARK: - Batch Management

    func createBatchFromSelected() {
        let ids = selectedUngroupedIDs
        guard !ids.isEmpty else { return }
        batchCounter += 1
        batches.append(Batch(label: "Batch \(batchCounter)", fileIDs: ids))
        selectedFileIDs.subtract(ids)
    }

    func addSelectedToBatch(batchID: UUID) {
        let ids = selectedUngroupedIDs
        guard !ids.isEmpty,
              let idx = batches.firstIndex(where: { $0.id == batchID }) else { return }
        batches[idx].fileIDs.append(contentsOf: ids)
        selectedFileIDs.subtract(ids)
    }

    func removeBatch(id: UUID) {
        switch editorTarget {
        case .batch(let bid) where bid == id:
            editorTarget = nil
        case .file(_, batchID: let bid) where bid == id:
            editorTarget = nil
        default:
            break
        }
        batches.removeAll { $0.id == id }
    }

    func removeFileFromBatch(fileID: UUID, batchID: UUID) {
        if editorTarget == .file(fileID, batchID: batchID) { editorTarget = nil }
        guard let idx = batches.firstIndex(where: { $0.id == batchID }) else { return }
        batches[idx].fileIDs.removeAll { $0 == fileID }
    }

    func moveBatches(from source: IndexSet, to destination: Int) {
        guard source.allSatisfy({ $0 >= 0 && $0 < batches.count }),
              destination >= 0, destination <= batches.count
        else { return }
        batches.move(fromOffsets: source, toOffset: destination)
    }

    func moveFilesInBatch(batchID: UUID, from source: IndexSet, to destination: Int) {
        guard let idx = batches.firstIndex(where: { $0.id == batchID }),
              source.allSatisfy({ $0 >= 0 && $0 < batches[idx].fileIDs.count }),
              destination >= 0, destination <= batches[idx].fileIDs.count
        else { return }
        batches[idx].fileIDs.move(fromOffsets: source, toOffset: destination)
    }

    func isExpandedBinding(for batchID: UUID) -> Binding<Bool> {
        Binding(
            get: { self.batches.first { $0.id == batchID }?.isExpanded ?? true },
            set: { newValue in
                if let idx = self.batches.firstIndex(where: { $0.id == batchID }) {
                    self.batches[idx].isExpanded = newValue
                }
            }
        )
    }

    // MARK: - Per‑File Overrides

    enum OverrideField { case width, height, padding, namePattern }

    func updateFile(id: UUID, _ transform: (inout ImageFile) -> Void) {
        guard let idx = _filesByID[id] else { return }
        transform(&allFiles[idx])
    }

    func resetFileOverride(id: UUID, field: OverrideField) {
        guard let idx = _filesByID[id] else { return }
        switch field {
        case .width:
            allFiles[idx].hasWidthOverride = false
            allFiles[idx].overrideWidth = ""
        case .height:
            allFiles[idx].hasHeightOverride = false
            allFiles[idx].overrideHeight = ""
        case .padding:
            allFiles[idx].hasPaddingOverride = false
            allFiles[idx].overridePadding = ""
        case .namePattern:
            allFiles[idx].hasNamePatternOverride = false
            allFiles[idx].overrideNamePattern = ""
        }
    }

    func overrideFieldFor(_ keyPath: WritableKeyPath<Batch, String>) -> OverrideField? {
        switch keyPath {
        case \.overrideWidth:       return .width
        case \.overrideHeight:      return .height
        case \.overridePadding:     return .padding
        case \.overrideNamePattern: return .namePattern
        default:                    return nil
        }
    }

    // MARK: - Batch Overrides (Tier 2)

    func resetBatchOverride(batchID: UUID, field: OverrideField) {
        guard let idx = batches.firstIndex(where: { $0.id == batchID }) else { return }
        switch field {
        case .width:
            batches[idx].hasWidthOverride = false
            batches[idx].overrideWidth = ""
        case .height:
            batches[idx].hasHeightOverride = false
            batches[idx].overrideHeight = ""
        case .padding:
            batches[idx].hasPaddingOverride = false
            batches[idx].overridePadding = ""
        case .namePattern:
            batches[idx].hasNamePatternOverride = false
            batches[idx].overrideNamePattern = ""
        }
    }

    // MARK: - Commit & Processing

    func commitChanges() {
        let activeBatches = batches.filter { !$0.fileIDs.isEmpty }
        guard !activeBatches.isEmpty else {
            alertTitle = "No Batches"
            alertMessage = "Create at least one batch with files before committing."
            showAlert = true
            return
        }

        let anyWithoutCrop = activeBatches.contains { batch in
            batch.fileIDs.contains { fileID in
                effectiveWidth(for: fileID, in: batch) == nil ||
                effectiveHeight(for: fileID, in: batch) == nil
            }
        }

        if anyWithoutCrop && !suppressNoCropWarning {
            showNoCropConfirmation = true
            return
        }

        executeCommit()
    }

    func confirmAndCommit() {
        showNoCropConfirmation = false
        executeCommit()
    }

    private func executeCommit() {
        let activeBatches = batches.filter { !$0.fileIDs.isEmpty }

        var workItems: [(sourceURL: URL, outputName: String, originalExtension: String,
                         width: Int?, height: Int?, padding: Int)] = []
        var nameRegistry: [String: String] = [:]
        var collisions: [String] = []

        for batch in activeBatches {
            for fileID in batch.fileIDs {
                guard let file = fileAt(id: fileID) else { continue }

                let name = outputName(for: fileID, in: batch)
                let w = effectiveWidth(for: fileID, in: batch)
                let h = effectiveHeight(for: fileID, in: batch)
                let hasCrop = w != nil && h != nil

                let ext = hasCrop ? "png" :
                    (file.originalURL.pathExtension.isEmpty ? "png" : file.originalURL.pathExtension)
                let fullName = "\(name).\(ext)"

                if let existing = nameRegistry[fullName] {
                    collisions.append(
                        "\"\(fullName)\" appears in \"\(existing)\" and \"\(batch.label)\""
                    )
                } else {
                    nameRegistry[fullName] = batch.label
                }

                let p = effectivePadding(for: fileID, in: batch)
                workItems.append((file.originalURL, name, file.originalURL.pathExtension,
                                  hasCrop ? w : nil, hasCrop ? h : nil, p))
            }
        }

        if !collisions.isEmpty {
            alertTitle = "Name Collision"
            alertMessage = "Multiple files would share an output name:\n\n"
                + collisions.joined(separator: "\n")
                + "\n\nResolve conflicts before committing."
            showAlert = true
            return
        }

        guard !workItems.isEmpty else {
            alertTitle = "Nothing to Process"
            alertMessage = "No files found in any batch."
            showAlert = true
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Destination"
        panel.message = "A new \"Converted Images\" folder will be created at the selected location containing your processed images."

        guard panel.runModal() == .OK, let baseURL = panel.url else { return }

        let outputDir = baseURL.appendingPathComponent("Converted Images")
        do {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        } catch {
            alertTitle = "Error"
            alertMessage = "Failed to create output folder:\n\(error.localizedDescription)"
            showAlert = true
            return
        }

        isProcessing = true
        progress = 0

        let items = workItems

        Task.detached(priority: .userInitiated) { [weak self] in
            let total = items.count
            var processed = 0
            var failures = 0
            var resized = 0
            var renamedOnly = 0

            for item in items {
                defer {
                    processed += 1
                    let p = Double(processed) / Double(total)
                    Task { @MainActor [weak self] in self?.progress = p }
                }

                if let width = item.width, let height = item.height {
                    let dest = outputDir.appendingPathComponent("\(item.outputName).png")
                    guard let cgImage = ImageProcessingService.processImage(
                        from: item.sourceURL,
                        canvasWidth: width,
                        canvasHeight: height,
                        padding: item.padding
                    ) else {
                        failures += 1
                        continue
                    }
                    if ImageProcessingService.savePNG(cgImage, to: dest) {
                        resized += 1
                    } else {
                        failures += 1
                    }
                } else {
                    let ext = item.originalExtension.isEmpty ? "png" : item.originalExtension
                    let dest = outputDir.appendingPathComponent("\(item.outputName).\(ext)")
                    do {
                        try FileManager.default.copyItem(at: item.sourceURL, to: dest)
                        renamedOnly += 1
                    } catch {
                        failures += 1
                    }
                }
            }

            let title: String
            let msg: String

            if failures == 0 {
                title = "Complete"
                var lines = ["Successfully processed all \(total) image(s)."]
                if resized > 0 { lines.append("  \u{2022} \(resized) resized") }
                if renamedOnly > 0 { lines.append("  \u{2022} \(renamedOnly) renamed (no resize)") }
                lines.append("\nSaved to:\n\(outputDir.path)")
                msg = lines.joined(separator: "\n")
            } else {
                title = "Completed with Issues"
                var lines = ["Processed \(total - failures) of \(total) image(s)."]
                if failures > 0 { lines.append("\(failures) failed.") }
                if resized > 0 { lines.append("  \u{2022} \(resized) resized") }
                if renamedOnly > 0 { lines.append("  \u{2022} \(renamedOnly) renamed (no resize)") }
                lines.append("\nSaved to:\n\(outputDir.path)")
                msg = lines.joined(separator: "\n")
            }

            await MainActor.run { [weak self] in
                self?.isProcessing = false
                self?.alertTitle = title
                self?.alertMessage = msg
                self?.showAlert = true
            }
        }
    }
}
