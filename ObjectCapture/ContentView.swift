//
//  ContentView.swift
//  ObjectCapture
//
//  Created by 최지한 on 5/27/25.
//

import RealityKit
import SwiftUI

struct ContentView: View {
    @State private var objectCaptureSession: ObjectCaptureSession?
    @State private var imageeFolderURL: URL?
    @State private var modelsFolderURL: URL?
    @State private var isProcessing = false
    @State private var isQuickLookPresented = false
    
    var modelFileURL: URL? {
        return modelsFolderURL?.appending(path: "model.usdz")
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if isProcessing {
                ProgressView("처리 중...")
            } else if let objectCaptureSession {
                ObjectCaptureView(session: objectCaptureSession)
                
                VStack {
                    if case .ready = objectCaptureSession.state {
                        Text("점을 물체 중앙에 맞춘 다음 감지 시작을 탭하세요.")
                            .foregroundStyle(.white)
                            .shadow(radius: 5)
                            .padding()
                        CreateButton(label: "감지 시작") {
                            _ = objectCaptureSession.startDetecting()
                        }
                    } else if case .detecting = objectCaptureSession.state {
                        Text("물체 전체가 박스 안에 있는지 확인하세요.")
                            .foregroundStyle(.white)
                            .shadow(radius: 5)
                            .padding()
                        CreateButton(label: "캡처 시작") {
                            objectCaptureSession.startCapturing()
                        }
                    }
                }
            } else if isQuickLookPresented {
                if let modelFileURL {
                    ARQuickLookView(modelFile: modelFileURL)
                }
            }
        }
        .task {
            guard let directory = createNewScanDirectory() else { return }
            objectCaptureSession = ObjectCaptureSession()
            
            modelsFolderURL = directory.appending(path: "Models/")
            imageeFolderURL = directory.appending(path: "Images/")
            guard let imageeFolderURL else { return }
            objectCaptureSession?.start(imagesDirectory: imageeFolderURL)
        }
        .onChange(of: objectCaptureSession?.userCompletedScanPass) {
            objectCaptureSession?.finish()
        }
        .onChange(of: objectCaptureSession?.state) { _, newValue in
            if newValue == .completed {
                objectCaptureSession = nil
                Task {
                    await startReconstruction()
                }
            }
        }
    }
    
    private func getRootScansFolder() -> URL? {
        guard let documentFolder = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        return documentFolder.appendingPathComponent("Scans/", isDirectory: true)
    }
    
    private func createNewScanDirectory() -> URL? {
        guard let capturesFolder = getRootScansFolder() else { return nil }
        
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let newCaptureDirectory = capturesFolder.appendingPathComponent(timestamp, isDirectory: true)
        print("캡처 경로 생성: \(newCaptureDirectory)")
        
        let capturePath = newCaptureDirectory.path
        do {
            try FileManager.default.createDirectory(atPath: capturePath, withIntermediateDirectories: true)
        } catch {
            print(error.localizedDescription)
        }
        
        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: capturePath, isDirectory: &isDirectory)
        print("새로운 캡처 경로가 생성되었습니다.")
        
        return newCaptureDirectory
    }
    
    private func startReconstruction() async {
        guard let imageeFolderURL, let modelFileURL else { return }
        
        withAnimation {
            isProcessing = true
        }
        
        do {
            let photogrammetrySession  = try PhotogrammetrySession(input: imageeFolderURL)
            try photogrammetrySession.process(requests: [
                .modelFile(url: modelFileURL)
            ])
            for try await output in photogrammetrySession.outputs {
                switch output {
                case .processingComplete:
                    withAnimation {
                        isProcessing = false
                    }
                    isQuickLookPresented = true
                default:
                    break
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct CreateButton: View {
    let action: () -> Void
    let label: String
    
    init(label: String, action: @escaping () -> Void) {
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(.headline)
                .padding(10)
        }
        .buttonStyle(.borderedProminent)
        .padding(.bottom, 50)
    }
}

#Preview {
    ContentView()
}
