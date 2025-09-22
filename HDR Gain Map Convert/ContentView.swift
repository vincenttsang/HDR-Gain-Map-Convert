//
//  ContentView.swift
//  HDR Gain Map Convert
//
//  Created by Vincent Tsang on 21/11/2024.
//

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
#if os(iOS)
import UIKit
import PhotosUI
import Photos
#endif

struct ContentView: View {
    @State private var sourceFilePaths: [String] = []
    @State private var outputDirectoryPath: String = ""
    // SwiftUI sheet presentation state for iOS pickers
    @State private var showSinglePicker: Bool = false
    @State private var showMultiPicker: Bool = false
    @State private var showDirectoryPicker: Bool = false
    // PhotoPicker states for iOS photo library access
    @State private var showSinglePhotoPicker: Bool = false
    @State private var showMultiPhotoPicker: Bool = false
    #if os(iOS)
    @State private var singlePhotoPickerItem: PhotosPickerItem? = nil
    @State private var multiPhotoPickerItems: [PhotosPickerItem] = []
    #endif
    // Export destination selection
    @State private var exportToPhotoLibrary: Bool = false
    // Persistent bookmark for output directory (iOS security-scoped)
    @State private var outputDirectoryBookmark: Data? = nil
    @State private var isSingleFileMode: Bool = true // 控制单个文件或多个文件模式
    @State private var progress: Double = 0.0 // 进度值
    @State private var isConverting: Bool = false // 是否正在转换
    @State private var colorSpace: String = "Rec. 2020"
    @State private var bitDepth: Int = 10
    @State private var outputPQ: Bool = false
    @State private var outputHLG: Bool = false
    @State private var outputSDR: Bool = false
    @State private var outputGooglePhotos: Bool = false
    @State private var threadCount: Int = 10
    @State private var imageQuality: Double = 0.95
    @State private var outputType: Int = 0
    
    let colorSpaces = ["sRGB", "Rec. 2020", "P3"]
    
    let fileTypes = [
        (id: 0, name: "HEIF"),
        (id: 1, name: "JPEG"),
        (id: 2, name: "PNG"),
        (id: 3, name: "TIFF")
    ]

    /**
     * outputType:
     * 0: HEIF
     * 1: JPEG
     * 2: PNG
     * 3: TIFF
     */
    var bitDepths: [Int] {
        switch outputType {
        case 1:
            // 输出JPEG图片时只允许使用8-Bit色深
            return [8]
            
        case 2, 3:
            // 输出类型为PNG或TIFF
            if outputPQ || outputHLG {
                // 输出PQ或HLG图片时只允许使用10-Bit以上色深
                return [10, 16]
            }
            return [8, 10, 16]
            
        case 0:
            // 输出类型为HEIF
            if outputPQ || outputHLG {
                // 输出PQ或HLG图片时只允许使用10-Bit以上色深
                return [10]
            }
            return [8, 10]
            
        default:
            // 其他情况，默认返回10-Bit
            return [10]
        }
    }
    
    let threadCounts = [2, 4, 6, 8, 10, 12, 14, 16]
    
    var body: some View {
        TabView(selection: $isSingleFileMode) {
            singleFileView()
                .tabItem {
                    Label(NSLocalizedString("single_file", comment: "Single file tab"), systemImage: "doc")
                }
                .tag(true)
        
            multipleFilesView()
                .tabItem {
                    Label(NSLocalizedString("multiple_files", comment: "Multiple files tab"), systemImage: "folder")
                }
                .tag(false)
        }
        .onAppear {
            requestNotificationPermission()
            // Try to restore persisted output directory bookmark (iOS)
            #if os(iOS)
            if let data = UserDefaults.standard.data(forKey: "outputDirectoryBookmark") {
                var isStale = false
                #if os(macOS)
                let resolveOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
                #else
                let resolveOptions: URL.BookmarkResolutionOptions = []
                #endif
                if let url = try? URL(resolvingBookmarkData: data, options: resolveOptions, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    // Try to access the security-scoped resource briefly to validate path
                    if url.startAccessingSecurityScopedResource() {
                        self.outputDirectoryPath = url.path
                        url.stopAccessingSecurityScopedResource()
                    } else {
                        self.outputDirectoryPath = url.path
                    }
                    self.outputDirectoryBookmark = data
                }
            }
            #endif
        }
        .padding()

        // iOS document picker sheets
        #if os(iOS)
        .sheet(isPresented: $showSinglePicker) {
            DocumentPickerView(contentTypes: [UTType.tiff, UTType.image, UTType.rawImage], allowsMultipleSelection: false, asCopy: true) { urls in
                if let url = urls.first {
                    self.sourceFilePaths = [url.path]
                }
            }
        }
        .sheet(isPresented: $showMultiPicker) {
            DocumentPickerView(contentTypes: [UTType.tiff, UTType.image, UTType.rawImage], allowsMultipleSelection: true, asCopy: true) { urls in
                self.sourceFilePaths = urls.map { $0.path }
            }
        }
        .sheet(isPresented: $showDirectoryPicker) {
            DocumentPickerView(contentTypes: [UTType.folder], allowsMultipleSelection: false, asCopy: false) { urls in
                if let url = urls.first {
                    // Create a persistent bookmark to allow re-opening the directory later
                    do {
                        #if os(macOS)
                        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        #else
                        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                        #endif
                        UserDefaults.standard.set(bookmark, forKey: "outputDirectoryBookmark")
                        self.outputDirectoryBookmark = bookmark
                        self.outputDirectoryPath = url.path
                    } catch {
                        print("Failed to create bookmark for output directory: \(error)")
                        self.outputDirectoryPath = url.path
                    }
                }
            }
        }
        .photosPicker(isPresented: $showSinglePhotoPicker, selection: $singlePhotoPickerItem, matching: .images)
        .photosPicker(isPresented: $showMultiPhotoPicker, selection: $multiPhotoPickerItems, matching: .images)
        .onChange(of: singlePhotoPickerItem) { _, newItem in
            Task {
                if let item = newItem {
                    await loadPhotoPickerItem(item: item, isMultiple: false)
                }
            }
        }
        .onChange(of: multiPhotoPickerItems) { _, newItems in
            Task {
                await loadPhotoPickerItems(items: newItems)
            }
        }
        #endif
    }
    
    private func settingsPanel(singleFile: Bool) -> some View {
        VStack {
            Spacer()
            Form {
                Section(header: Text(NSLocalizedString("color_space", comment: "Color space section header"))) {
                    Picker(NSLocalizedString("select_color_space", comment: "Color space picker"), selection: $colorSpace) {
                        ForEach(colorSpaces, id: \.self) {
                            Text($0)
                        }
                    }
                }
                
                Section(header: Text(NSLocalizedString("output_file_type", comment: "Output file type section header"))) {
                                Picker(NSLocalizedString("select_file_type", comment: "File type picker"), selection: $outputType) {
                                    ForEach(fileTypes, id: \.id) { fileType in
                                        Text(fileType.name).tag(fileType.id)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle()) // 可选样式
                            }
                
                Section(header: Text(NSLocalizedString("bit_depth", comment: "Bit depth section header"))) {
                    Picker(NSLocalizedString("select_bit_depth", comment: "Bit depth picker"), selection: $bitDepth) {
                        ForEach(bitDepths, id: \.self) {
                            Text(String(format: NSLocalizedString("bit", comment: "Bit depth label"), $0))
                        }
                    }
                    .onChange(of: bitDepths) {
                        if !bitDepths.contains(bitDepth) {
                            bitDepth = bitDepths.last ?? 8
                        }
                    }
                }
                
                Spacer()
                
                self.outputOptions()
                
                Spacer()
                
                Section(header: Text(NSLocalizedString("image_quality", comment: "Image quality section header"))) {
                    Slider(value: $imageQuality, in: 0.01...1.0, step: 0.01)
                        .padding()
                    Text(String(format: NSLocalizedString("selected_quality", comment: "Selected quality label"), imageQuality))
                        .padding()
                }
                
                if !singleFile {
                    Section(header: Text(NSLocalizedString("concurrency", comment: "Concurrency section header"))) {
                        Picker(NSLocalizedString("select_thread_count", comment: "Thread count picker"), selection: $threadCount) {
                            ForEach(threadCounts, id: \.self) {
                                Text(String(format: NSLocalizedString("threads", comment: "Thread count label"), $0))
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("image_converter_settings", comment: "Navigation title"))
        }
        
    }
    
    private func outputOptions() -> some View {
        Section(header: Text(NSLocalizedString("output_options", comment: "Output options section header"))) {
            #if os(iOS)
            Toggle(NSLocalizedString("export_to_photo_library", comment: "Export to photo library toggle"), isOn: $exportToPhotoLibrary)
                .onChange(of: exportToPhotoLibrary) {
                    if exportToPhotoLibrary {
                        outputDirectoryPath = NSLocalizedString("photo_library", comment: "Photo library destination")
                    } else {
                        outputDirectoryPath = ""
                    }
                }
            #endif
            
            Toggle(NSLocalizedString("output_pq_image", comment: "PQ output toggle"), isOn: $outputPQ)
                .disabled(outputHLG || outputSDR || outputGooglePhotos)
                .onChange(of: outputPQ, {
                    outputHLG = false
                    outputSDR = false
                    outputGooglePhotos = false
                })
            
            Toggle(NSLocalizedString("output_hlg_image", comment: "HLG output toggle"), isOn: $outputHLG)
                .disabled(outputPQ || outputSDR || outputGooglePhotos)
                .onChange(of: outputHLG, {
                    outputPQ = false
                    outputSDR = false
                    outputGooglePhotos = false
                })
            
            
            Toggle(NSLocalizedString("output_sdr_image", comment: "SDR output toggle"), isOn: $outputSDR)
                .disabled(outputPQ || outputHLG || outputGooglePhotos)
                .onChange(of: outputSDR, {
                    outputPQ = false
                    outputHLG = false
                    outputGooglePhotos = false
                })
            
            Toggle(NSLocalizedString("output_google_photos", comment: "Google Photos output toggle"), isOn: $outputGooglePhotos)
                .disabled(outputPQ || outputHLG || outputSDR)
                .onChange(of: outputGooglePhotos, {
                    outputPQ = false
                    outputHLG = false
                    outputSDR = false
                })
            
        }
    }
    
    // 单个文件视图
    private func singleFileView() -> some View {
        HStack {
            VStack {
                Text(NSLocalizedString("select_single_source_file", comment: "Single source file header"))
                    .font(.headline)
                    .padding()
                
                TextField(NSLocalizedString("source_file_path", comment: "Source file path placeholder"), text: Binding(
                    get: { sourceFilePaths.first ?? "" },
                    set: { _ in }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .disabled(true)
                
                Button(NSLocalizedString("select_source_file", comment: "Select source file button")) {
                    #if os(iOS)
                    showSinglePicker = true
                    #else
                    selectSourceFile()
                    #endif
                }
                .padding()
                
                #if os(iOS)
                Button(NSLocalizedString("select_from_photo_library", comment: "Select from photo library button")) {
                    showSinglePhotoPicker = true
                }
                .padding()
                #endif
                
                TextField(NSLocalizedString("output_directory_path", comment: "Output directory path placeholder"), text: $outputDirectoryPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .disabled(true)
                
                #if os(iOS)
                if !exportToPhotoLibrary {
                    Button(NSLocalizedString("select_output_directory", comment: "Select output directory button")) {
                        showDirectoryPicker = true
                    }
                    .padding()
                }
                #else
                Button(NSLocalizedString("select_output_directory", comment: "Select output directory button")) {
                    selectOutputDirectory()
                }
                .padding()
                #endif
                
                Button(NSLocalizedString("convert_image", comment: "Convert image button")) {
                    convertImage()
                }
                .padding()
                .buttonStyle(.borderedProminent)
#if os(iOS)
                    .disabled(sourceFilePaths.isEmpty || !exportToPhotoLibrary && outputDirectoryPath.isEmpty)
#else
                    .disabled(sourceFilePaths.isEmpty || outputDirectoryPath.isEmpty)
#endif
            }
            settingsPanel(singleFile: true)
        }
    }
    
    // 多个文件视图
    private func multipleFilesView() -> some View {
        VStack {
            HStack {
                VStack {
                    Text(NSLocalizedString("select_multiple_source_files", comment: "Multiple source files header"))
                        .font(.headline)
                        .padding()
                    
                    List(sourceFilePaths, id: \.self) { path in
                        Text(path)
                    }
                    
                    Button(NSLocalizedString("select_multiple_source_files_button", comment: "Select multiple source files button")) {
                        #if os(iOS)
                        showMultiPicker = true
                        #else
                        selectMultipleSourceFiles()
                        #endif
                    }
                    .padding()
                    
                    #if os(iOS)
                    Button(NSLocalizedString("select_from_photo_library_multiple", comment: "Select multiple from photo library button")) {
                        showMultiPhotoPicker = true
                    }
                    .padding()
                    #endif
                    
                    TextField(NSLocalizedString("output_directory_path", comment: "Output directory path placeholder"), text: $outputDirectoryPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .disabled(true)
                    
                    #if os(iOS)
                    if !exportToPhotoLibrary {
                        Button(NSLocalizedString("select_output_directory", comment: "Select output directory button")) {
                            showDirectoryPicker = true
                        }
                        .padding()
                    }
                    #else
                    Button(NSLocalizedString("select_output_directory", comment: "Select output directory button")) {
                        selectOutputDirectory()
                    }
                    .padding()
                    #endif
                    
                    Button(NSLocalizedString("convert_images", comment: "Convert images button")) {
                        convertImages()
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
#if os(iOS)
                    .disabled(sourceFilePaths.isEmpty || !exportToPhotoLibrary && outputDirectoryPath.isEmpty)
#else
                    .disabled(sourceFilePaths.isEmpty || outputDirectoryPath.isEmpty)
#endif
                }
                settingsPanel(singleFile: false)
            }
            if isConverting {
                ProgressView(NSLocalizedString("conversion_progress", comment: "Conversion progress label"), value: progress, total: Double(sourceFilePaths.count))
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
            }
        }
        
    }
    
#if os(macOS)
    private func selectSourceFile() {
        let dialog = NSOpenPanel()
        dialog.title = NSLocalizedString("select_source_file_dialog", comment: "Select source file dialog title")
        dialog.allowedContentTypes = [UTType.tiff, UTType.image, UTType.rawImage]
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        
        dialog.begin { result in
            if result == .OK, let url = dialog.url {
                sourceFilePaths = [url.path] // 更新为单个文件路径
            }
        }
    }
#endif
    
#if os(macOS)
    private func selectMultipleSourceFiles() {
        let dialog = NSOpenPanel()
        dialog.title = NSLocalizedString("select_multiple_source_files_dialog", comment: "Select multiple source files dialog title")
        dialog.allowedContentTypes = [UTType.tiff, UTType.image, UTType.rawImage]
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        dialog.allowsMultipleSelection = true // 允许选择多个文件
        
        dialog.begin { result in
            if result == .OK {
                sourceFilePaths = dialog.urls.map { $0.path } // 更新为多个文件路径
            }
        }
    }
#endif
    
#if os(macOS)
    private func selectOutputDirectory() {
        let dialog = NSOpenPanel()
        dialog.title = NSLocalizedString("select_output_directory_dialog", comment: "Select output directory dialog title")
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        dialog.canCreateDirectories = true
        
        dialog.begin { result in
            if result == .OK, let url = dialog.url {
                outputDirectoryPath = url.path
            }
        }
    }
#endif

#if os(iOS)
    private func selectSourceFile() {
        // deprecated: replaced by SwiftUI sheet with DocumentPickerView
    }
#endif

#if os(iOS)
    private func selectMultipleSourceFiles() {
        // deprecated: replaced by SwiftUI sheet with DocumentPickerView
    }
#endif

#if os(iOS)
    private func selectOutputDirectory() {
        // deprecated: replaced by SwiftUI sheet with DocumentPickerView
    }
#endif

// MARK: - Photo Library Functions
#if os(iOS)
private func loadPhotoPickerItem(item: PhotosPickerItem, isMultiple: Bool) async {
    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
    
    // Create temporary file for the image data
    let tempDirectory = FileManager.default.temporaryDirectory
    let tempFileName = "\(UUID().uuidString).\(item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg")"
    let tempURL = tempDirectory.appendingPathComponent(tempFileName)
    
    do {
        try data.write(to: tempURL)
        await MainActor.run {
            if isMultiple {
                self.sourceFilePaths.append(tempURL.path)
            } else {
                self.sourceFilePaths = [tempURL.path]
            }
        }
    } catch {
        print("Failed to save photo picker item: \(error)")
    }
}

private func loadPhotoPickerItems(items: [PhotosPickerItem]) async {
    var paths: [String] = []
    
    for item in items {
        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileName = "\(UUID().uuidString).\(item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg")"
        let tempURL = tempDirectory.appendingPathComponent(tempFileName)
        
        do {
            try data.write(to: tempURL)
            paths.append(tempURL.path)
        } catch {
            print("Failed to save photo picker item: \(error)")
        }
    }
    
    await MainActor.run {
        self.sourceFilePaths = paths
    }
}

private func saveImageToPhotoLibrary(imagePath: String) {
    // Check if file exists first
    guard FileManager.default.fileExists(atPath: imagePath) else {
        print("File does not exist at path: \(imagePath)")
        return
    }
    
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        switch status {
        case .authorized, .limited:
            // Try to save using the file URL directly for better format preservation
            let fileURL = URL(fileURLWithPath: imagePath)
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: fileURL, options: nil)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Image saved to photo library successfully: \(imagePath)")
                        // Clean up temporary file
                        try? FileManager.default.removeItem(atPath: imagePath)
                    } else if let error = error {
                        print("Error saving image to photo library: \(error)")
                        // Fallback: try with UIImage
                        self.saveImageFallback(imagePath: imagePath)
                    }
                }
            }
        case .denied, .restricted:
            print("Photo library access denied or restricted")
        case .notDetermined:
            print("Photo library access not determined")
        @unknown default:
            print("Unknown photo library authorization status")
        }
    }
}

private func saveImageFallback(imagePath: String) {
    guard let image = UIImage(contentsOfFile: imagePath) else {
        print("Failed to load image from path for fallback: \(imagePath)")
        return
    }
    
    PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
    }) { success, error in
        DispatchQueue.main.async {
            if success {
                print("Image saved to photo library successfully (fallback): \(imagePath)")
            } else if let error = error {
                print("Error saving image to photo library (fallback): \(error)")
            }
            // Clean up temporary file
            try? FileManager.default.removeItem(atPath: imagePath)
        }
    }
}
#endif

// MARK: - UIDocumentPicker helper
#if os(iOS)

/// SwiftUI wrapper for UIDocumentPickerViewController
struct DocumentPickerView: UIViewControllerRepresentable {
    var contentTypes: [UTType]
    var allowsMultipleSelection: Bool = false
    var asCopy: Bool = true
    var completion: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: asCopy)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = allowsMultipleSelection
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: ([URL]) -> Void

        init(completion: @escaping ([URL]) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion([])
        }
    }
}

#endif
    
    private func convertImage() {
        print(String(format: NSLocalizedString("source_file", comment: "Source file log"), sourceFilePaths.first ?? ""))
        print(String(format: NSLocalizedString("output_directory", comment: "Output directory log"), outputDirectoryPath))
        
        #if os(iOS)
        if exportToPhotoLibrary {
            // Use temporary directory for photo library export
            let actualOutputPath = FileManager.default.temporaryDirectory.path
            convertAndSaveToLibrary(outputPath: actualOutputPath)
        } else {
            // Use security-scoped resource for file system export
            convertToFileSystem()
        }
        #else
        let converter = Converter(src: sourceFilePaths.first ?? "", dest: outputDirectoryPath, imageQuality: imageQuality, colorSpace: colorSpace, colorDepth: bitDepth, SDR: outputSDR, PQ: outputPQ, HLG: outputHLG, Google: outputGooglePhotos, outputType: outputType)
        let result = converter.convert()
        
        if result == 0 {
            print(NSLocalizedString("converted", comment: "Conversion success log"))
            sendNotification()
        } else {
            print(NSLocalizedString("failed", comment: "Conversion failure log"))
        }
        #endif
    }
    
    #if os(iOS)
    private func convertToFileSystem() {
        guard let bookmarkData = outputDirectoryBookmark else {
            print("❌ Error: No output directory bookmark available")
            return
        }
        
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            print("❌ Error: Failed to resolve bookmark data")
            return
        }
        
        print("📁 Attempting to access directory: \(url.path)")
        
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Error: Failed to access security-scoped resource")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
            print("🔓 Released security-scoped resource")
        }
        
        print("✅ Successfully accessed security-scoped resource")
        
        let converter = Converter(src: sourceFilePaths.first ?? "", dest: url.path, imageQuality: imageQuality, colorSpace: colorSpace, colorDepth: bitDepth, SDR: outputSDR, PQ: outputPQ, HLG: outputHLG, Google: outputGooglePhotos, outputType: outputType)
        let result = converter.convert()
        
        if result == 0 {
            print("✅ " + NSLocalizedString("converted", comment: "Conversion success log"))
            sendNotification()
        } else {
            print("❌ " + NSLocalizedString("failed", comment: "Conversion failure log"))
        }
    }
    
    private func convertAndSaveToLibrary(outputPath: String) {
        let converter = Converter(src: sourceFilePaths.first ?? "", dest: outputPath, imageQuality: imageQuality, colorSpace: colorSpace, colorDepth: bitDepth, SDR: outputSDR, PQ: outputPQ, HLG: outputHLG, Google: outputGooglePhotos, outputType: outputType)
        let result = converter.convert()
        
        if result == 0 {
            print("✅ " + NSLocalizedString("converted", comment: "Conversion success log"))
            
            // Find the converted file and save to photo library
            let sourceFileName = URL(fileURLWithPath: sourceFilePaths.first ?? "").deletingPathExtension().lastPathComponent
            let outputExtension = getOutputExtension()
            let convertedFilePath = "\(outputPath)/\(sourceFileName).\(outputExtension)"
            
            print("🔍 Looking for converted file at: \(convertedFilePath)")
            
            // List all files in the temporary directory for debugging
            do {
                let tempFiles = try FileManager.default.contentsOfDirectory(atPath: outputPath)
                print("📁 Files in temp directory: \(tempFiles)")
                
                // Try to find the file with case-insensitive search
                if let foundFile = tempFiles.first(where: { $0.lowercased().hasPrefix(sourceFileName.lowercased()) }) {
                    let actualPath = "\(outputPath)/\(foundFile)"
                    print("✅ Found converted file: \(actualPath)")
                    saveImageToPhotoLibrary(imagePath: actualPath)
                } else {
                    print("❌ Converted file not found. Expected: \(convertedFilePath)")
                }
            } catch {
                print("❌ Error listing temp directory: \(error)")
            }
            
            sendNotification()
        } else {
            print("❌ " + NSLocalizedString("failed", comment: "Conversion failure log"))
        }
    }
    
    private func getOutputExtension() -> String {
        switch outputType {
        case 0: return "HEIC"  // 使用大寫以匹配Converter類
        case 1: return "JPG"   // 使用JPG而不是jpg
        case 2: return "PNG"
        case 3: return "TIFF"
        default: return "HEIC"
        }
    }
    #endif
    
    private func convertImages() {
        isConverting = true
        progress = 0.0
        
        #if os(iOS)
        if exportToPhotoLibrary {
            // Use temporary directory for photo library export
            let actualOutputPath = FileManager.default.temporaryDirectory.path
            processBatchesForLibrary(sourceFilePaths, outputPath: actualOutputPath)
        } else {
            // Use security-scoped resource for file system export
            processBatchesForFileSystem(sourceFilePaths)
        }
        #else
        // Process files in manageable batches to avoid exhausting system resources
        let batchSize = threadCount
        let fileBatches = sourceFilePaths.chunked(into: batchSize)
        processBatches(fileBatches, currentBatchIndex: 0)
        #endif
    }
    
    #if os(iOS)
    private func processBatchesForLibrary(_ filePaths: [String], outputPath: String) {
        let batchSize = threadCount
        let fileBatches = filePaths.chunked(into: batchSize)
        processBatchesLibrary(fileBatches, outputPath: outputPath, currentBatchIndex: 0)
    }
    
    private func processBatchesForFileSystem(_ filePaths: [String]) {
        guard let bookmarkData = outputDirectoryBookmark else {
            print("No output directory bookmark available")
            DispatchQueue.main.async {
                self.isConverting = false
            }
            return
        }
        
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
              url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            DispatchQueue.main.async {
                self.isConverting = false
            }
            return
        }
        
        let batchSize = threadCount
        let fileBatches = filePaths.chunked(into: batchSize)
        processBatchesFileSystem(fileBatches, outputURL: url, currentBatchIndex: 0)
    }
    
    private func processBatchesLibrary(_ batches: [[String]], outputPath: String, currentBatchIndex: Int) {
        guard currentBatchIndex < batches.count else {
            // All batches completed
            DispatchQueue.main.async {
                self.isConverting = false
                self.sendNotification()
            }
            return
        }
        
        let currentBatch = batches[currentBatchIndex]
        let queue = DispatchQueue(label: "org.image.converter.batch\(currentBatchIndex)", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: min(threadCount, 16))
        
        for path in currentBatch {
            group.enter()
            
            queue.async {
                semaphore.wait()
                
                autoreleasepool {
                    let converter = Converter(
                        src: path,
                        dest: outputPath,
                        imageQuality: self.imageQuality,
                        colorSpace: self.colorSpace,
                        colorDepth: self.bitDepth,
                        SDR: self.outputSDR,
                        PQ: self.outputPQ,
                        HLG: self.outputHLG,
                        Google: self.outputGooglePhotos,
                        outputType: self.outputType
                    )
                    let result = converter.convert()
                    if result == 0 {
                        print(String(format: NSLocalizedString("converted_image", comment: "Converted image log"), path))
                        
                        // Save to photo library - use improved file finding logic
                        let sourceFileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                        
                        do {
                            let tempFiles = try FileManager.default.contentsOfDirectory(atPath: outputPath)
                            
                            // Try to find the file with case-insensitive search
                            if let foundFile = tempFiles.first(where: { $0.lowercased().hasPrefix(sourceFileName.lowercased()) }) {
                                let actualPath = "\(outputPath)/\(foundFile)"
                                DispatchQueue.main.async {
                                    self.saveImageToPhotoLibrary(imagePath: actualPath)
                                }
                            } else {
                                print("❌ Converted file not found for: \(sourceFileName)")
                            }
                        } catch {
                            print("❌ Error listing temp directory: \(error)")
                        }
                    } else {
                        print(String(format: NSLocalizedString("failed_to_convert_image", comment: "Failed to convert image log"), path))
                    }
                }
                
                DispatchQueue.main.async {
                    self.progress += 1.0
                }
                
                semaphore.signal()
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.main) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.processBatchesLibrary(batches, outputPath: outputPath, currentBatchIndex: currentBatchIndex + 1)
            }
        }
    }
    
    private func processBatchesFileSystem(_ batches: [[String]], outputURL: URL, currentBatchIndex: Int) {
        guard currentBatchIndex < batches.count else {
            // All batches completed
            DispatchQueue.main.async {
                outputURL.stopAccessingSecurityScopedResource()
                self.isConverting = false
                self.sendNotification()
            }
            return
        }
        
        let currentBatch = batches[currentBatchIndex]
        let queue = DispatchQueue(label: "org.image.converter.batch\(currentBatchIndex)", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: min(threadCount, 16))
        
        for path in currentBatch {
            group.enter()
            
            queue.async {
                semaphore.wait()
                
                autoreleasepool {
                    let converter = Converter(
                        src: path,
                        dest: outputURL.path,
                        imageQuality: self.imageQuality,
                        colorSpace: self.colorSpace,
                        colorDepth: self.bitDepth,
                        SDR: self.outputSDR,
                        PQ: self.outputPQ,
                        HLG: self.outputHLG,
                        Google: self.outputGooglePhotos,
                        outputType: self.outputType
                    )
                    let result = converter.convert()
                    if result == 0 {
                        print(String(format: NSLocalizedString("converted_image", comment: "Converted image log"), path))
                    } else {
                        print(String(format: NSLocalizedString("failed_to_convert_image", comment: "Failed to convert image log"), path))
                    }
                }
                
                DispatchQueue.main.async {
                    self.progress += 1.0
                }
                
                semaphore.signal()
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.main) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.processBatchesFileSystem(batches, outputURL: outputURL, currentBatchIndex: currentBatchIndex + 1)
            }
        }
    }
    #endif
    
    #if os(macOS)
    private func processBatches(_ batches: [[String]], currentBatchIndex: Int) {
        guard currentBatchIndex < batches.count else {
            // All batches completed
            DispatchQueue.main.async {
                self.isConverting = false
                print(String(format: NSLocalizedString("output_directory", comment: "Output directory log"), self.outputDirectoryPath))
                self.sendNotification()
            }
            return
        }
        
        let currentBatch = batches[currentBatchIndex]
        let queue = DispatchQueue(label: "org.image.converter.batch\(currentBatchIndex)", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: min(threadCount, 16)) // Limit to max 16 concurrent operations per batch
        
        print(String(format: NSLocalizedString("processing_batch", comment: "Processing batch log"), currentBatchIndex + 1, batches.count, currentBatch.count))
        
        for path in currentBatch {
            group.enter()
            
            queue.async {
                semaphore.wait()
                
                // Create converter for each file but ensure proper cleanup
                autoreleasepool {
                    let converter = Converter(
                        src: path, 
                        dest: self.outputDirectoryPath, 
                        imageQuality: self.imageQuality, 
                        colorSpace: self.colorSpace, 
                        colorDepth: self.bitDepth, 
                        SDR: self.outputSDR, 
                        PQ: self.outputPQ, 
                        HLG: self.outputHLG, 
                        Google: self.outputGooglePhotos, 
                        outputType: self.outputType
                    )
                    let result = converter.convert()
                    if result == 0 {
                        print(String(format: NSLocalizedString("converted_image", comment: "Converted image log"), path))
                    } else {
                        print(String(format: NSLocalizedString("failed_to_convert_image", comment: "Failed to convert image log"), path))
                    }
                }
                
                // Update progress
                DispatchQueue.main.async {
                    self.progress += 1.0
                }
                
                semaphore.signal()
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.main) {
            // Add a small delay between batches to allow system cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Force garbage collection between batches
                self.forceMemoryCleanup()
                
                // Process next batch
                self.processBatches(batches, currentBatchIndex: currentBatchIndex + 1)
            }
        }
    }
    #endif
    
    private func forceMemoryCleanup() {
        // Force memory cleanup between batches
        autoreleasepool {
            // Trigger garbage collection
            if #available(macOS 10.12, *) {
                // Force memory pressure to clean up resources
                DispatchQueue.global(qos: .utility).async {
                    // This helps trigger cleanup of accumulated resources
                    let _ = Array(repeating: 0, count: 1000)
                }
            }
        }
    }
    
    // 请求通知权限
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print(String(format: NSLocalizedString("notification_permission_error", comment: "Notification permission error"), error.localizedDescription))
            }
        }
    }
    
    // 发送通知
    func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("conversion_complete", comment: "Notification title")
        content.body = NSLocalizedString("conversion_complete_body", comment: "Notification body")
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print(String(format: NSLocalizedString("notification_send_error", comment: "Notification send error"), error.localizedDescription))
            }
        }
    }
    
    // 在 Finder 中查看文件夹
#if os(macOS)
    func openInFinder() {
        let url = URL(fileURLWithPath: outputDirectoryPath)
        NSWorkspace.shared.open(url)
    }
#endif
}

// MARK: - Array Extension for Batch Processing
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    ContentView()
}
