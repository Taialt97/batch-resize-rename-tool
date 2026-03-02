import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            GlobalSettingsView(viewModel: viewModel)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            FileListView(viewModel: viewModel)
            
            Divider()
            
            BottomBar(viewModel: viewModel)
        }
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                viewModel.addFiles(urls: urls)
            }
        }
        .alert(isPresented: $viewModel.showSuccessAlert) {
            Alert(
                title: Text("Batch Complete"),
                message: Text(viewModel.processingMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// MARK: - Bottom Bar

struct BottomBar: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        HStack {
            if viewModel.totalCount > 0 {
                Text("Processed: \(viewModel.processedCount)/\(viewModel.totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if viewModel.isProcessing {
                ProgressView()
                    .scaleEffect(0.6)
                    .padding(.trailing, 8)
            }
            
            Button("Commit Changes") {
                pickFolderAndProcess()
            }
            .disabled(viewModel.items.isEmpty || viewModel.isProcessing)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func pickFolderAndProcess() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Destination Folder"
        
        // Use beginSheetModal to avoid blocking the main run loop
        guard let window = NSApp.keyWindow else {
            // Fallback: use begin() without a parent window
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    viewModel.processAll(destinationDirectory: url)
                }
            }
            return
        }
        
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                viewModel.processAll(destinationDirectory: url)
            }
        }
    }
}

// MARK: - Global Settings

struct GlobalSettingsView: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global Settings")
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Canvas Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("Width", text: $viewModel.globalTargetWidth)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 70)
                        Text("x")
                        TextField("Height", text: $viewModel.globalTargetHeight)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 70)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider().frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Renaming Pattern")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("Prefix", text: $viewModel.globalPrefix)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 120)
                        
                        Text("[Original Name]")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .background(Color(nsColor: .controlColor).opacity(0.5))
                            .cornerRadius(4)
                        
                        TextField("Suffix", text: $viewModel.globalSuffix)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 120)
                    }
                }
            }
        }
    }
}

// MARK: - File List

struct FileListView: View {
    @ObservedObject var viewModel: ViewModel
    @State private var isTargeted = false
    
    var body: some View {
        ZStack {
            if viewModel.items.isEmpty {
                emptyState
            } else {
                populatedList
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Drag and Drop Images Here")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Supports PNG, JPG, TIFF, HEIC")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Or Select Files...") {
                viewModel.showingFileImporter = true
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
    }
    
    private var populatedList: some View {
        List {
            ForEach($viewModel.items) { $item in
                ImageRowView(item: $item, viewModel: viewModel)
            }
            .onDelete(perform: viewModel.removeItems)
        }
        .listStyle(InsetListStyle())
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    viewModel.addFiles(urls: [url])
                }
            }
        }
        return true
    }
}

// MARK: - Image Row

struct ImageRowView: View {
    @Binding var item: ImageItem
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 200, alignment: .leading)
                    .help(item.originalURL.path)
                
                Text(item.displayOriginalSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider().frame(height: 30)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Name")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField(
                        "\(viewModel.globalPrefix)\(item.originalName)\(viewModel.globalSuffix)",
                        text: $item.overrideName
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 180)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Size Override")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        TextField(viewModel.globalTargetWidth, text: $item.overrideWidth)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                        Text("x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(viewModel.globalTargetHeight, text: $item.overrideHeight)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                    }
                }
            }
            
            Spacer()
            
            statusIcon
                .frame(width: 24)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            if !item.overrideName.isEmpty || !item.overrideWidth.isEmpty || !item.overrideHeight.isEmpty {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
                    .help("Custom overrides applied")
            }
        case .processing:
            ProgressView().scaleEffect(0.5)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failure(let msg):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .help(msg)
        }
    }
}
