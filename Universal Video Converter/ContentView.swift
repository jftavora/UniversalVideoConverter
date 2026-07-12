//
//  ContentView.swift
//  Universal Video Converter
//
//  Created by João Fernando Távora on 12/06/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var converter = VideoConverterEngine()
    
    // Core file tracking states
    @State private var localInputURL: URL? = nil
    @State private var localSubtitleURL: URL? = nil
    
    @State private var currentFileName = ""
    @State private var currentSubName = ""
    
    @State private var fileSelected = false
    @State private var subSelected = false
    
    // Sheet toggles
    @State private var isShowingVideoPicker = false
    @State private var isShowingSubtitlePicker = false
    
    @State private var selectedExtension = "mp4"
    let targetExtensions = ["mp4", "mkv", "mov", "avi"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Native Video Converter")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            
            // 1. Interactive File Selector Box
            Button(action: { isShowingVideoPicker = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            converter.isConverting ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2, dash: [6])
                        )
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    
                    VStack(spacing: 12) {
                        if fileSelected {
                            Image(systemName: "video.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            Text(currentFileName)
                                .font(.headline)
                                .lineLimit(1)
                        } else {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("Click to select target video source file")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: 100)
            .disabled(converter.isConverting)
            // FIXED: Attached the Video Importer directly to its own button view
            .fileImporter(
                isPresented: $isShowingVideoPicker,
                allowedContentTypes: [.movie, .video, .audiovisualContent, .quickTimeMovie, .mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                DispatchQueue.main.async {
                    if case .success(let urls) = result, let selectedURL = urls.first {
                        if selectedURL.startAccessingSecurityScopedResource() {
                            self.localInputURL = selectedURL
                            self.currentFileName = selectedURL.lastPathComponent
                            self.fileSelected = true
                            self.converter.conversionStatus = "Ready to process"
                        }
                    }
                }
            }
            
            // 2. OPTIONAL SUBTITLE PICKER ROW
            HStack {
                Button(action: { isShowingSubtitlePicker = true }) {
                    HStack {
                        Image(systemName: subSelected ? "captions.bubble.fill" : "plus.circle")
                            .foregroundColor(subSelected ? .green : .secondary)
                        Text(subSelected ? currentSubName : "Add Optional Subtitles (.srt)")
                            .font(.callout)
                            .foregroundColor(subSelected ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!fileSelected || converter.isConverting)
                // FIXED: Attached the Subtitle Importer directly to its own button view
                .fileImporter(
                    isPresented: $isShowingSubtitlePicker,
                    allowedContentTypes: [.item, .plainText, .text, .data],
                    allowsMultipleSelection: false
                ) { result in
                    DispatchQueue.main.async {
                        if case .success(let urls) = result, let selectedURL = urls.first {
                            if selectedURL.startAccessingSecurityScopedResource() {
                                self.localSubtitleURL = selectedURL
                                self.currentSubName = selectedURL.lastPathComponent
                                self.subSelected = true
                            }
                        }
                    }
                }
                
                if subSelected {
                    Button(action: removeSubtitles) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(converter.isConverting)
                }
            }
            
            // Format Picker
            HStack(spacing: 15) {
                Text("Target Format:")
                    .fontWeight(.medium)
                
                Picker("", selection: $selectedExtension) {
                    ForEach(targetExtensions, id: \.self) { ext in
                        Text(ext.uppercased()).tag(ext)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(converter.isConverting)
            }
            
            Divider()
            
            // Custom Equalizer Bars Panel
            if converter.isConverting {
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            VerticalBarIndicator(index: index)
                        }
                    }
                    .frame(height: 30)
                    
                    Text("Processing tracks...")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity)
            } else {
                Spacer().frame(height: 54)
            }
            
            // Action Panel Layout
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(converter.isConverting ? .orange : (fileSelected ? .green : .secondary))
                    
                    Text(converter.conversionStatus)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: startNativeProcessing) {
                    if converter.isConverting {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Remuxing...")
                        }
                        .frame(width: 110)
                    } else {
                        Text("Run Native Remux")
                            .frame(width: 110)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!fileSelected || converter.isConverting)
            }
        }
        .padding(25)
        .frame(width: 500, height: 410)
    }
    
    private func removeSubtitles() {
        localSubtitleURL?.stopAccessingSecurityScopedResource()
        localSubtitleURL = nil
        currentSubName = ""
        subSelected = false
    }
    
    private func startNativeProcessing() {
        guard let url = localInputURL else { return }
        converter.isConverting = true
        converter.convertVideo(inputURL: url, subtitleURL: localSubtitleURL, outputExtension: selectedExtension)
    }
}
// MARK: - Custom Equalizer Animation View
struct VerticalBarIndicator: View {
    let index: Int
    @State private var isAnimating = false
    
    // Vary the animation speeds so the bars jump independently
    var animationDuration: Double {
        return [0.4, 0.6, 0.5, 0.7, 0.4][index % 5]
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor)
            // Toggles between a short bar and a tall bar
            .frame(width: 4, height: isAnimating ? 32 : 8)
            .onAppear {
                // Creates a continuous, repeating jump loop
                withAnimation(
                    .easeInOut(duration: animationDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
            .onDisappear {
                isAnimating = false
            }
    }
}
