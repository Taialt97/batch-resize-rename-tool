import Foundation

struct Batch: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var fileIDs: [UUID] = []
    var isExpanded: Bool = true

    // Tier 2 overrides — when set, these override Global (Tier 1)
    // for every file in this batch (unless the file itself has a Tier 3 override).
    var overrideWidth: String = ""
    var overrideHeight: String = ""
    var overridePadding: String = ""
    var overrideNamePattern: String = ""
    var hasWidthOverride = false
    var hasHeightOverride = false
    var hasPaddingOverride = false
    var hasNamePatternOverride = false
}
