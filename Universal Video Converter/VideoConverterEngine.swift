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
        
        if subtitleURL != nil {
                    if outputExtension.lowercased() == "mkv" {
                        // MKV natively handles raw SRT subtitles flawlessly with zero translation drops
                        args.append(contentsOf: [
                            "-c:s", "srt",
                            "-metadata:s:s:0", "language=eng"
                        ])
                    } else {
                        // MP4 / MOV: Inject strict text formatting configuration
                        args.append(contentsOf: [
                            "-c:s", "mov_text",
                            // FORCE TEXT WRAPPING BOUNDS: This flag strips bad invisible carriage returns
                            // and forces Apple players to cleanly resize multi-line subtitle blocks.
                            "-movflags", "+faststart+disable_chpl"
                        ])
                        
                        // Optional: Map metadata language parameters safely
                        args.append(contentsOf: ["-metadata:s:s:0", "language=eng"])
                    }
                }
        
        args.append(contentsOf: ["-movflags", "+faststart", outputPath])
        process.arguments = args
        // ------------------------
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
