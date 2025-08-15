import SwiftUI
import Foundation

struct LinkPreviewView: View {
    let url: String
    @State private var previewData: LinkPreviewData?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
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
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
            .frame(height: 120)
            .overlay(
                HStack(spacing: 12) {
                    // 左侧图标/图片
                    VStack {
                        if let iconURL = preview.iconURL, !iconURL.isEmpty {
                            AsyncImage(url: URL(string: iconURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                defaultIcon
                            }
                            .frame(width: 32, height: 32)
                            .cornerRadius(6)
                        } else {
                            defaultIcon
                        }
                        
                        Spacer()
                    }
                    
                    // 右侧内容
                    VStack(alignment: .leading, spacing: 4) {
                        // 标题
                        if let title = preview.title, !title.isEmpty {
                            Text(title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        
                        // 描述
                        if let description = preview.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        // 域名
                        if let domain = preview.domain {
                            Text(domain)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(12)
            )
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
    
    private func loadPreview() {
        guard !isLoading, previewData == nil else { return }
        
        isLoading = true
        
        // 模拟异步加载（实际实现中可能需要网络请求）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 简单的预览数据生成
            if let url = URL(string: url) {
                let domain = url.host ?? "Unknown"
                let title = generateTitle(from: url)
                let description = "Visit \(domain) for more information"
                
                previewData = LinkPreviewData(
                    title: title,
                    description: description,
                    domain: domain,
                    iconURL: nil
                )
            }
            
            isLoading = false
        }
    }
    
    private func generateTitle(from url: URL) -> String {
        let host = url.host ?? "Website"
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        if let lastComponent = pathComponents.last {
            return lastComponent.replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        } else {
            return host.capitalized
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