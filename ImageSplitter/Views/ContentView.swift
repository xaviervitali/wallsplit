import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    @State private var selectedTab: Tab = .split
    
    enum Tab: String, CaseIterable {
        case split = "Split"
        case browse = "Browse"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar + toolbar
            HStack(spacing: 0) {
                // Tabs
                HStack(spacing: 2) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab == .split ? "rectangle.split.3x1" : "photo.on.rectangle.angled")
                                    .font(.caption)
                                Text(tab.rawValue).font(.callout.weight(selectedTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.12) : .clear,
                                       in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    }
                }
                .padding(.leading, 16)
                
                if selectedTab == .split {
                    ToolbarView()
                } else {
                    Spacer()
                }
            }
            
            Divider()
            
            // Content
            switch selectedTab {
            case .split:
                splitView
            case .browse:
                BrowseView(onImageLoaded: {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = .split }
                }).environmentObject(viewModel)
            }
        }
        .alert("Export Complete", isPresented: $viewModel.showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: { Text("\(viewModel.exportedCount) wallpapers saved.") }
        .alert(viewModel.wallpaperResultIsError ? "Error" : "Wallpapers Applied",
               isPresented: $viewModel.showWallpaperResult) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.wallpaperResultMessage) }
        .sheet(isPresented: $viewModel.showSavePreset) { SavePresetSheet().environmentObject(viewModel) }
        .sheet(isPresented: $viewModel.showHelp) { HelpView() }
        .onDrop(of: [.image, .fileURL], isTargeted: $viewModel.isDragging) { viewModel.handleDrop(providers: $0) }
    }
    
    private var splitView: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ScreenListView()
                }
            }
            .frame(width: 280)
            Divider()
            ZStack {
                if viewModel.sourceImage != nil {
                    ScreenLayoutView().padding(16)
                } else {
                    CurrentWallpaperView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))

            if let tileId = viewModel.selectedTileId,
               let tile = viewModel.tiles.first(where: { $0.id == tileId }) {
                Divider()
                TileDetailView(tile: tile)
            }
        }
    }
}

private struct SavePresetSheet: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save Preset").font(.title3.weight(.semibold))
            TextField("e.g. Home Office 3 screens", text: $viewModel.presetName)
                .textFieldStyle(.roundedBorder).focused($focused)
                .onSubmit { viewModel.saveCurrentAsPreset() }
            HStack {
                Button("Cancel") { viewModel.showSavePreset = false; viewModel.presetName = "" }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { viewModel.saveCurrentAsPreset() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(viewModel.presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24).frame(width: 380)
        .onAppear { focused = true }
    }
}
