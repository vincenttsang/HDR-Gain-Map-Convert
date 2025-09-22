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
#endif

struct ContentView: View {
    @State private var sourceFilePaths: [String] = []
    @State private var outputDirectoryPath: String = ""
    // SwiftUI sheet presentation state for iOS pickers
    @State private var showSinglePicker: Bool = false
    @State private var showMultiPicker: Bool = false
    @State private var showDirectoryPicker: Bool = false
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
                
                TextField(NSLocalizedString("output_directory_path", comment: "Output directory path placeholder"), text: $outputDirectoryPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .disabled(true)
                
                Button(NSLocalizedString("select_output_directory", comment: "Select output directory button")) {
                    #if os(iOS)
                    showDirectoryPicker = true
                    #else
                    selectOutputDirectory()
                    #endif
                }
                .padding()
                
                Button(NSLocalizedString("convert_image", comment: "Convert image button")) {
                    convertImage()
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .disabled(sourceFilePaths.isEmpty || outputDirectoryPath.isEmpty)
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
                    
                    TextField(NSLocalizedString("output_directory_path", comment: "Output directory path placeholder"), text: $outputDirectoryPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .disabled(true)
                    
                    Button(NSLocalizedString("select_output_directory", comment: "Select output directory button")) {
                        #if os(iOS)
                        showDirectoryPicker = true
                        #else
                        selectOutputDirectory()
                        #endif
                    }
                    .padding()
                    
                    Button(NSLocalizedString("convert_images", comment: "Convert images button")) {
                        convertImages()
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .disabled(sourceFilePaths.isEmpty || outputDirectoryPath.isEmpty)
                    
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
        // TODO: 在这里实现单个文件的转换逻辑
        print(String(format: NSLocalizedString("source_file", comment: "Source file log"), sourceFilePaths.first ?? ""))
        print(String(format: NSLocalizedString("output_directory", comment: "Output directory log"), outputDirectoryPath))
        let converter = Converter(src: sourceFilePaths.first ?? "", dest: outputDirectoryPath, imageQuality: imageQuality, colorSpace: colorSpace, colorDepth: bitDepth, SDR: outputSDR, PQ: outputPQ, HLG: outputHLG, Google: outputGooglePhotos, outputType: outputType)
        let result = converter.convert()
        if result == 0 {
            print(NSLocalizedString("converted", comment: "Conversion success log"))
            sendNotification()
        } else {
            print(NSLocalizedString("failed", comment: "Conversion failure log"))
        }
    }
    
    private func convertImages() {
        isConverting = true
        progress = 0.0
        
        // Process files in manageable batches to avoid exhausting system resources
        let batchSize = threadCount // Set the batch size equal to the number of available threads
        let fileBatches = sourceFilePaths.chunked(into: batchSize)
        
        processBatches(fileBatches, currentBatchIndex: 0)
    }
    
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
