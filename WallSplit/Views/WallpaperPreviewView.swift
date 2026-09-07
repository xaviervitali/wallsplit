import SwiftUI

// MARK: - WallpaperPreviewView
//
// Shows the source image with split-boundary lines overlaid.
// Lets the user confirm the split before applying wallpapers.

struct WallpaperPreviewView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    var onApplied: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            previewArea
        }
        .frame(width: 900, height: 660)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Header

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview").font(.headline)
                    Text("Adjust layout, then apply")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                let count = viewModel.screenManager.screens.count
                Text("\(count) screen\(count != 1 ? "s" : "")")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary))

                Button("Cancel") { viewModel.showPreviewOverlay = false }
                    .buttonStyle(.bordered)

                Button {
                    viewModel.regenerateTiles()
                    viewModel.showPreviewOverlay = false
                    viewModel.applyWallpapers()
                    onApplied?()
                } label: {
                    Label("Apply Wallpapers", systemImage: "desktopcomputer")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.sourceImage == nil)
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)

            // Layout controls
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Text("Fit:").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $viewModel.fitMode) {
                        ForEach(WallSplitService.FitMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }

                if viewModel.fitMode != .stretch {
                    AnchorPicker(anchorX: $viewModel.anchorX, anchorY: $viewModel.anchorY)

                    Button {
                        viewModel.smartCrop()
                    } label: {
                        if viewModel.isSmartCropping {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.small)
                                Text("Analyzing…").font(.callout)
                            }
                        } else {
                            Label("Smart Crop", systemImage: "sparkles.rectangle.stack").font(.callout)
                        }
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(viewModel.isSmartCropping)
                }

                Spacer()
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: Preview area

    private var previewArea: some View {
        Group {
            if let image = viewModel.sourceImage {
                GeometryReader { geo in
                    ZStack {
                        Color.black.opacity(0.88)
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        SplitLinesOverlay(
                            image: image,
                            screens: viewModel.screenManager.screens,
                            boundingBox: viewModel.screenManager.boundingBox,
                            fitMode: viewModel.fitMode,
                            anchorX: viewModel.anchorX,
                            anchorY: viewModel.anchorY,
                            containerSize: geo.size
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo").font(.title).foregroundStyle(.tertiary)
                    Text("No image loaded").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - SplitLinesOverlay

struct SplitLinesOverlay: View {
    let image: NSImage
    let screens: [ScreenInfo]
    let boundingBox: CGRect
    let fitMode: WallSplitService.FitMode
    let anchorX: CGFloat
    let anchorY: CGFloat
    let containerSize: CGSize

    // Pixel dimensions of the source image
    private var imgSize: CGSize {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CGSize(width: CGFloat(cg.width), height: CGFloat(cg.height))
        }
        return image.size
    }

    // Mapping: bb coord → image pixel coord (mirrors WallSplitService.computeMapping)
    private var mapping: (sx: CGFloat, sy: CGFloat, ox: CGFloat, oy: CGFloat) {
        let iw = imgSize.width, ih = imgSize.height
        let bw = boundingBox.width, bh = boundingBox.height
        switch fitMode {
        case .stretch: return (iw / bw, ih / bh, 0, 0)
        case .fill:
            let s = max(iw / bw, ih / bh)
            return (s, s, (iw - bw * s) * anchorX, (ih - bh * s) * anchorY)
        case .fit:
            let s = min(iw / bw, ih / bh)
            return (s, s, (iw - bw * s) * anchorX, (ih - bh * s) * anchorY)
        }
    }

    // How the image is rendered in containerSize with aspectRatio(.fit)
    private var displayScale: (ds: CGFloat, dox: CGFloat, doy: CGFloat) {
        let img = imgSize
        let ds = min(containerSize.width / img.width, containerSize.height / img.height)
        let dox = (containerSize.width - img.width * ds) / 2
        let doy = (containerSize.height - img.height * ds) / 2
        return (ds, dox, doy)
    }

    var body: some View {
        let (sx, sy, ox, oy) = mapping
        let (ds, dox, doy) = displayScale
        let bb = boundingBox
        let img = imgSize

        Canvas { ctx, _ in
            // Dim region outside the bounding box
            let imageRect = CGRect(x: dox, y: doy, width: img.width * ds, height: img.height * ds)
            let bbRect = CGRect(
                x: dox + ox * ds,
                y: doy + oy * ds,
                width: bb.width * sx * ds,
                height: bb.height * sy * ds
            )
            if imageRect.size != bbRect.size || imageRect.origin != bbRect.origin {
                var dimPath = Path()
                dimPath.addRect(imageRect)
                dimPath.addRect(bbRect.insetBy(dx: -0.5, dy: -0.5))
                ctx.fill(dimPath, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
            }
            // Screen boundary boxes
            for screen in screens {
                let relX = screen.originX - bb.minX
                let relY = screen.originY - bb.minY
                let x = dox + (ox + relX * sx) * ds
                let y = doy + (oy + relY * sy) * ds
                let w = screen.width * sx * ds
                let h = screen.height * sy * ds
                let r = CGRect(x: x, y: y, width: w, height: h)
                ctx.stroke(Path(r), with: .color(.black.opacity(0.55)), lineWidth: 3)
                ctx.stroke(Path(r), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .overlay(alignment: .topLeading) {
            ForEach(screens) { screen in
                screenLabel(
                    screen: screen,
                    sx: sx, sy: sy, ox: ox, oy: oy,
                    ds: ds, dox: dox, doy: doy
                )
            }
        }
    }

    // Extract label into a function to avoid ViewBuilder type-inference issues
    @ViewBuilder
    private func screenLabel(
        screen: ScreenInfo,
        sx: CGFloat, sy: CGFloat, ox: CGFloat, oy: CGFloat,
        ds: CGFloat, dox: CGFloat, doy: CGFloat
    ) -> some View {
        let relX = screen.originX - boundingBox.minX
        let relY = screen.originY - boundingBox.minY
        let x = dox + (ox + relX * sx) * ds
        let y = doy + (oy + relY * sy) * ds
        let w = screen.width * sx * ds
        let h = screen.height * sy * ds
        VStack(spacing: 1) {
            Text(screen.name)
                .font(.system(size: max(9, min(14, w * 0.07)), weight: .semibold))
            Text(screen.resolution)
                .font(.system(size: max(8, min(11, w * 0.055)), design: .monospaced))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 5))
        .position(x: x + w / 2, y: y + h / 2)
    }
}
