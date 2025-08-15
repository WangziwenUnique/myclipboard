import SwiftUI
import Foundation

struct LinkPreviewView: View {
    let url: String
    @State private var previewData: LinkPreviewData?
    @State private var isLoading = false
    @State private var hasError = false
    @StateObject private var metadataService = LinkMetadataService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if hasError {
                errorView
            } else if let preview = previewData {
                previewCard(preview: preview)
            } else {
                placeholderView
            }
        }
        .onAppear {
            loadPreview()
        }
    }
    
    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
            .frame(height: 120)
            .overlay(
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                    
                    Text("Loading preview...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }
    
    private var errorView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
            .frame(height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("Preview Unavailable")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    if let domain = URL(string: url)?.host {
                        Text(domain)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Button("Retry") {
                        loadPreview()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
            .frame(height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    
                    Text("Link Preview")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    if let domain = URL(string: url)?.host {
                        Text(domain)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }
    
    private func previewCard(preview: LinkPreviewData) -> some View {
        VStack(spacing: 0) {
            // 上部80% - 图片区域
            Group {
                if let iconURL = preview.iconURL, !iconURL.isEmpty {
                    AsyncImage(url: URL(string: iconURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        largeDefaultIcon
                    }
                } else {
                    largeDefaultIcon
                }
            }
            .frame(height: 160)
            .frame(width: 280)
            .clipped()
            
            // 下部20% - 文本区域
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                if let title = preview.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(width: 256, alignment: .leading)
                }
                
                // 描述
                if let description = preview.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(width: 256, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 50)
            .frame(width: 280)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var defaultIcon: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "link")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            )
    }
    
    private var largeDefaultIcon: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
            .overlay(
                Image(systemName: "link")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
            )
    }
    
    private func loadPreview() {
        guard !isLoading else { return }
        
        isLoading = true
        hasError = false
        
        Task {
            let metadata = await metadataService.fetchMetadata(for: url)
            
            await MainActor.run {
                isLoading = false
                
                if let metadata = metadata {
                    previewData = metadata
                    hasError = false
                } else {
                    hasError = true
                }
            }
        }
    }
    
}

struct LinkPreviewData {
    let title: String?
    let description: String?
    let domain: String?
    let iconURL: String?
}

#Preview {
    LinkPreviewView(url: "https://anthropic.com/output-styles")
        .background(Color.black)
        .frame(width: 300, height: 200)
}