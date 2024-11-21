//
//  ContentView.swift
//  HDR Gain Map Convert
//
//  Created by Vincent Tsang on 21/11/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var sourceFilePaths: [String] = []
    @State private var outputDirectoryPath: String = ""
    @State private var isSingleFileMode: Bool = true // 控制单个文件或多个文件模式
    @State private var progress: Double = 0.0 // 进度值
    @State private var isConverting: Bool = false // 是否正在转换
    private let maxConcurrentTasks = 16 // 最大并发任务数

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
        .padding()
    }

    // 单个文件视图
    private func singleFileView() -> some View {
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
    }

    // 多个文件视图
    private func multipleFilesView() -> some View {
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
        let converter = Converter(src: sourceFilePaths.first ?? "", dest: outputDirectoryPath, imageQuality: 1.0, colorSpace: "p3", colorDepth: 10, SDR: false, PQ: false, HLG: false)
        let result = converter.convert()
        if result == 0 {
            print("Converted")
        } else {
            print("Failed")
        }
    }

    private func convertImages() {
        isConverting = true
        progress = 0.0
        let queue = DispatchQueue(label: "com.example.imageConverter", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: maxConcurrentTasks) // 创建信号量

        for path in sourceFilePaths {
            group.enter() // 进入组
            
            // 在并发队列中执行转换
            queue.async {
                semaphore.wait() // 等待信号量

                let converter = Converter(src: path, dest: outputDirectoryPath, imageQuality: 1.0, colorSpace: "p3", colorDepth: 10, SDR: false, PQ: false, HLG: false)
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
        }
    }
}


#Preview {
    ContentView()
}
