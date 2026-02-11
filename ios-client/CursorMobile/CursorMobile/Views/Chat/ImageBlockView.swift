import SwiftUI

/// View that displays an image block with thumbnail and tap-to-expand functionality
struct ImageBlockView: View {
    let block: ChatContentBlock
    @State private var showFullScreen = false
    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = loadedImage {
                thumbnailView(image: image)
                    .onTapGesture {
                        showFullScreen = true
                    }
                    .fullScreenCover(isPresented: $showFullScreen) {
                        FullScreenImageView(image: image, isPresented: $showFullScreen)
                    }
            } else {
                placeholderView
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func thumbnailView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: 200, maxHeight: 200)
            .clipped()
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(width: 200, height: 200)

            VStack(spacing: 8) {
                ProgressView()
                Text("Loading image...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func loadImage() {
        guard let base64String = block.imageData,
              let imageData = Data(base64Encoded: base64String),
              let image = UIImage(data: imageData) else {
            print("[ImageBlockView] Failed to load image from base64 data")
            return
        }

        loadedImage = image
    }
}

/// Full-screen image viewer with zoom and pan
struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }

                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }

                Spacer()
            }
        }
    }
}

#Preview {
    // Create a sample image for preview
    let sampleImage = UIImage(systemName: "photo")!
    let imageData = sampleImage.pngData()!.base64EncodedString()

    let block = ChatContentBlock(
        id: "preview",
        type: .image,
        timestamp: Date().timeIntervalSince1970,
        imageData: imageData,
        mimeType: "image/png"
    )

    return ImageBlockView(block: block)
        .padding()
}
