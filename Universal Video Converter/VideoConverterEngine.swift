//
//  VideoConverterEngine.swift
//  Universal Video Converter
//
//  Created by João Fernando Távora on 12/06/26.
//

import SwiftUI
import Foundation

@Observable
class VideoConverterEngine {
    var isConverting = false
    var conversionStatus = "Ready"
    
    func convertVideo(inputURL: URL, subtitleURL: URL?, outputExtension: String) {
        let videoAccessGranted = inputURL.startAccessingSecurityScopedResource()
        let subAccessGranted = subtitleURL?.startAccessingSecurityScopedResource() ?? false
        
        DispatchQueue.main.async {
            self.isConverting = true
            self.conversionStatus = "Multiplexing video, audio, and subtitle streams..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.processBundleRemux(inputURL: inputURL, subtitleURL: subtitleURL, outputExtension: outputExtension)
            
            DispatchQueue.main.async {
                if videoAccessGranted { inputURL.stopAccessingSecurityScopedResource() }
                if subAccessGranted { subtitleURL?.stopAccessingSecurityScopedResource() }
                
                self.isConverting = false
                self.conversionStatus = success ? "Conversion Successful!" : "Conversion Failed."
            }
        }
    }
    
    private func processBundleRemux(inputURL: URL, subtitleURL: URL?, outputExtension: String) -> Bool {
        let inputPath = inputURL.path
        let outputPath = inputURL.deletingPathExtension().appendingPathExtension(outputExtension).path
        
        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(atPath: outputPath)
        }
        
        guard let bundledFFmpegURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) else {
            return false
        }
        
        let process = Process()
        process.executableURL = bundledFFmpegURL
        
        // --- COMMAND BUILDING ---
        var args = ["-fflags", "+genpts", "-i", inputPath]
        
        // If a subtitle URL exists, inject it as the second input stream (-i)
        if let subPath = subtitleURL?.path {
            args.append(contentsOf: ["-i", subPath])
        }
        
        // Map streams and copy codecs
                args.append(contentsOf: [
                    "-c:v", "copy", // Copy video stream directly
                    "-c:a", "aac",  // Transcode audio track to native Apple AAC
                    "-b:a", "192k"
                ])
                
                // Remove the hardcoded -tag:v hvc1 line that broke H.264 streams.
                // Faststart alone handles index placement and compatibility for both H.264 and H.265!
                if outputExtension.lowercased() == "mp4" || outputExtension.lowercased() == "mov" {
                    args.append(contentsOf: ["-movflags", "+faststart"])
                }
                
                if subtitleURL != nil {
                    if outputExtension.lowercased() == "mkv" {
                        args.append(contentsOf: [
                            "-c:s", "srt",
                            "-metadata:s:s:0", "language=eng"
                        ])
                    } else {
                        args.append(contentsOf: [
                            "-c:s", "mov_text",
                            "-metadata:s:s:0", "language=eng"
                        ])
                    }
                }
                
                args.append(outputPath)
                process.arguments = args
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
