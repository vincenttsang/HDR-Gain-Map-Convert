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
    @State private var threadCount: Int = 10
    @State private var imageQuality: Double = 0.85

    let colorSpaces = ["sRGB", "Rec. 2020", "P3"]
    let bitDepths = [8, 10]
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
                Form {
                    Section(header: Text("Color Space")) {
                        Picker("Select Color Space", selection: $colorSpace) {
                            ForEach(colorSpaces, id: \.self) {
                                Text($0)
                            }
                        }
                    }

                    Section(header: Text("Bit Depth")) {
                        Picker("Select Bit Depth", selection: $bitDepth) {
                            ForEach(bitDepths, id: \.self) {
                                Text("\($0)-Bit")
                            }
                        }
                    }

                    Section(header: Text("Output Options")) {
                        Toggle("Output PQ Image", isOn: $outputPQ)
                        Toggle("Output HLG Image", isOn: $outputHLG)
                        Toggle("Output SDR Image", isOn: $outputSDR)
                    }
                    
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
        let converter = Converter(src: sourceFilePaths.first ?? "", dest: outputDirectoryPath, imageQuality: imageQuality, colorSpace: colorSpace, colorDepth: bitDepth, SDR: outputSDR, PQ: outputPQ, HLG: outputHLG)
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
        let queue = DispatchQueue(label: "org.image.onverter", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: threadCount) // 创建信号量

        for path in sourceFilePaths {
            group.enter() // 进入组
            
            // 在并发队列中执行转换
            queue.async {
                semaphore.wait() // 等待信号量
                
                // 使用当前路径而不是第一个元素
                let converter = Converter(src: path, dest: outputDirectoryPath, imageQuality: imageQuality, colorSpace: colorSpace, colorDepth: bitDepth, SDR: outputSDR, PQ: outputPQ, HLG: outputHLG)
                let result = converter.convert()
                if result == 0 {
                    print("Converted image: \(path)")
                } else {
                    print("Failed to convert image: \(path)")
                }

                // 更新进度
                DispatchQueue.main.async {
                    progress += 1.0
                }

                semaphore.signal() // 释放信号量
                group.leave() // 离开组
            }
        }

        group.notify(queue: DispatchQueue.main) {
            isConverting = false
            print("输出目录: \(outputDirectoryPath)")
            sendNotification()
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


#Preview {
    ContentView()
}
