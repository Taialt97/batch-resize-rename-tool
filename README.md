# Batch Resize & Rename Tool

A native macOS desktop application for batch resizing and renaming image files. Built with SwiftUI and CoreGraphics.

Import images, organize them into batches, apply global or per-file settings, and export everything in one operation.

## Features

- **Drag-and-drop import** — drop image files directly into the window or use the file picker. Supports PNG, JPEG, TIFF, BMP, GIF, HEIC, and WebP.
- **Batch organization** — group selected files into named batches. Reorder batches and files within batches via drag and drop.
- **3-tier settings cascade** — set dimensions and naming patterns at the global, batch, or individual file level. More specific tiers override less specific ones.
- **Canvas resize (no crop/warp)** — images are scaled to fit strictly within the target canvas while maintaining aspect ratio, with transparent padding filling the remainder.
- **Rename-only mode** — rename files without resizing. If no crop dimensions are set, files are copied with the new name and original format preserved.
- **Sequential naming** — use bracket syntax (`[000]`) in patterns to insert zero-padded sequence numbers. Continuous numbering across batches or per-batch numbering.
- **Visual status indicators** — color-coded icons per file show whether rename/crop settings come from global (green), batch (orange), file (blue), or none (gray).
- **Collision detection** — warns before committing if multiple files would produce the same output filename.
- **Background processing** — image processing runs off the main thread with a progress bar.

## Download

Pre-built `.app` binaries are available on the [Releases](../../releases) page.

Download the latest `.zip`, extract it, and move `Batch Resize & Rename Tool.app` to your Applications folder.

> **Note:** The app is not notarized. On first launch, right-click the app and select "Open" to bypass Gatekeeper, or go to System Settings > Privacy & Security and click "Open Anyway".

## Build from Source

### Requirements

- macOS 13.0+
- Xcode 15.0+

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/Taialt97/batch-resize-rename-tool.git
   cd batch-resize-rename-tool
   ```

2. Open the Xcode project:
   ```bash
   open "Batch Resize & Rename Tool.xcodeproj"
   ```

3. Select the **Batch Resize & Rename Tool** scheme and press **Cmd+R** to build and run.

## Usage

1. **Import images** — drag files into the window or click "Add Files".
2. **Select and batch** — click files in the ungrouped pool to select them, then click "Create Batch".
3. **Configure settings** — set global width, height, padding, and naming pattern in the top panel. Override at the batch or file level by expanding the override fields.
4. **Commit** — click "Commit Changes", choose a destination folder, and the tool creates a "Converted Images" subfolder with all processed files.

### Naming Pattern Syntax

| Pattern | File 1 | File 2 | File 10 |
|---|---|---|---|
| `Hero_[00]` | `Hero_01` | `Hero_02` | `Hero_10` |
| `icon_[0000]_sm` | `icon_0001_sm` | `icon_0002_sm` | `icon_0010_sm` |

The number of zeros inside the brackets sets the minimum digit width.

## Project Structure

```
Batch Resize & Rename Tool/
├── BatchResizeRenameToolApp.swift     # App entry point
├── Models/
│   ├── Batch.swift                    # Batch data model
│   └── ImageFile.swift                # Image file data model + thumbnail generation
├── ViewModels/
│   └── BatchProcessorViewModel.swift  # Central state management and processing logic
├── Views/
│   ├── ContentView.swift              # Main window layout
│   ├── GlobalSettingsPanel.swift      # Global settings UI
│   ├── FileListView.swift             # File list with batches and ungrouped files
│   └── BatchFileRowView.swift         # Individual file row with override fields
└── Services/
    └── ImageProcessingService.swift   # CoreGraphics resize and PNG export
```

## License

This project is licensed under the **PolyForm Noncommercial License 1.0.0**.

You are free to view, download, and use the source code for any **non-commercial purpose** — personal projects, learning, research, education, etc.

**Commercial use is strictly prohibited.** You may not sell this application, include it in a commercial product, or use the source code to build software for commercial purposes.

See [LICENSE](LICENSE) for the full legal text.
