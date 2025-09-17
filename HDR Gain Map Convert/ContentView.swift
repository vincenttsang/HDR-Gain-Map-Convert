//
//  ContentView.swift
//  HDR Gain Map Convert
//
//  Created by Vincent Tsang on 21/11/2024.
//

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct ContentView: View {
    @State private var sourceFilePaths: [String] = []
    @State private var outputDirectoryPath: String = ""
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
                    Label("单个文件", systemImage: "doc")
                }
                .tag(true)
        
            multipleFilesView()
                .tabItem {
                    Label("多个文件", systemImage: "folder")
                }
                .tag(false)
        }
        .onAppear {
            requestNotificationPermission()
        }
        .padding()
    }
    
    private func settingsPanel(singleFile: Bool) -> some View {
        VStack {
            Spacer()
            Form {
                Section(header: Text("Color Space")) {
                    Picker("Select Color Space", selection: $colorSpace) {
                        ForEach(colorSpaces, id: \.self) {
                            Text($0)
                        }
                    }
                }
                
                Section(header: Text("Output File Type")) {
                                Picker("Select File Type", selection: $outputType) {
                                    ForEach(fileTypes, id: \.id) { fileType in
                                        Text(fileType.name).tag(fileType.id)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle()) // 可选样式
                            }
                
                Section(header: Text("Bit Depth")) {
                    Picker("Select Bit Depth", selection: $bitDepth) {
                        ForEach(bitDepths, id: \.self) {
                            Text("\($0)-Bit")
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
                
                Section(header: Text("Image Quality")) {
                    Slider(value: $imageQuality, in: 0.01...1.0, step: 0.01)
                        .padding()
                    Text("Selected Quality: \(imageQuality, specifier: "%.2f")")
                        .padding()
                }
                
                if !singleFile {
                    Section(header: Text("Concurrency")) {
                        Picker("Select Thread Count", selection: $threadCount) {
                            ForEach(threadCounts, id: \.self) {
                                Text("\($0) Threads")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Image Converter Settings")
        }
        
    }
    
    private func outputOptions() -> some View {
        Section(header: Text("Output Options")) {
            Toggle("Output PQ Image", isOn: $outputPQ)
                .disabled(outputHLG || outputSDR || outputGooglePhotos)
                .onChange(of: outputPQ, {
                    outputHLG = false
                    outputSDR = false
                    outputGooglePhotos = false
                })
            
            Toggle("Output HLG Image", isOn: $outputHLG)
                .disabled(outputPQ || outputSDR || outputGooglePhotos)
                .onChange(of: outputHLG, {
                    outputPQ = false
                    outputSDR = false
                    outputGooglePhotos = false
                })
            
            
            Toggle("Output SDR Image", isOn: $outputSDR)
                .disabled(outputPQ || outputHLG || outputGooglePhotos)
                .onChange(of: outputSDR, {
                    outputPQ = false
                    outputHLG = false
                    outputGooglePhotos = false
                })
            
            Toggle("Output Google Photos Compatible HDR Image", isOn: $outputGooglePhotos)
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
                Text("选择单个源文件")
                    .font(.headline)
                    .padding()
                
                TextField("源文件路径", text: Binding(
                    get: { sourceFilePaths.first ?? "" },
                    set: { _ in }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .disabled(true)
                
                Button("选择源文件") {
                    selectSourceFile()
                }
                .padding()
                
                TextField("输出目录路径", text: $outputDirectoryPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .disabled(true)
                
                Button("选择输出目录") {
                    selectOutputDirectory()
                }
                .padding()
                
                Button("转换图片") {
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
                    Text("选择多个源文件")
                        .font(.headline)
                        .padding()
                    
                    List(sourceFilePaths, id: \.self) { path in
                        Text(path)
                    }
                    
                    Button("选择多个源文件") {
                        selectMultipleSourceFiles()
                    }
                    .padding()
                    
                    TextField("输出目录路径", text: $outputDirectoryPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .disabled(true)
                    
                    Button("选择输出目录") {
                        selectOutputDirectory()
                    }
                    .padding()
                    
                    Button("转换图片") {
                        convertImages()
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .disabled(sourceFilePaths.isEmpty || outputDirectoryPath.isEmpty)
                    
                }
                settingsPanel(singleFile: false)
            }
            if isConverting {
                ProgressView("转换进度", value: progress, total: Double(sourceFilePaths.count))
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
            }
        }
        
    }
    
    private func selectSourceFile() {
        let dialog = NSOpenPanel()
        dialog.title = "选择源文件"
        dialog.allowedContentTypes = [UTType.tiff, UTType.image, UTType.rawImage]
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        
        dialog.begin { result in
            if result == .OK, let url = dialog.url {
                sourceFilePaths = [url.path] // 更新为单个文件路径
            }
        }
    }
    
    private func selectMultipleSourceFiles() {
        let dialog = NSOpenPanel()
        dialog.title = "选择多个源文件"
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
    
    private func selectOutputDirectory() {
        let dialog = NSOpenPanel()
        dialog.title = "选择输出目录"
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
    
    private func convertImage() {
        // TODO: 在这里实现单个文件的转换逻辑
        print("源文件: \(sourceFilePaths.first ?? "")")
        print("输出目录: \(outputDirectoryPath)")
        let converter = Converter(src: sourceFilePaths.first ?? "", dest: outputDirectoryPath, imageQuality: imageQuality, colorSpace: colorSpace, colorDepth: bitDepth, SDR: outputSDR, PQ: outputPQ, HLG: outputHLG, Google: outputGooglePhotos, outputType: outputType)
        let result = converter.convert()
        if result == 0 {
            print("Converted")
            sendNotification()
        } else {
            print("Failed")
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
                print("输出目录: \(self.outputDirectoryPath)")
                self.sendNotification()
            }
            return
        }
        
        let currentBatch = batches[currentBatchIndex]
        let queue = DispatchQueue(label: "org.image.converter.batch\(currentBatchIndex)", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: min(threadCount, 16)) // Limit to max 16 concurrent operations per batch
        
        print("Processing batch \(currentBatchIndex + 1)/\(batches.count) with \(currentBatch.count) files")
        
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
                        print("Converted image: \(path)")
                    } else {
                        print("Failed to convert image: \(path)")
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
                print("请求通知权限时出错: \(error.localizedDescription)")
            }
        }
    }
    
    // 发送通知
    func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "转换完成"
        content.body = "您的相片已转换完成，点击查看。"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送通知时出错: \(error.localizedDescription)")
            }
        }
    }
    
    // 在 Finder 中查看文件夹
    func openInFinder() {
        let url = URL(fileURLWithPath: outputDirectoryPath)
        NSWorkspace.shared.open(url)
    }
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
