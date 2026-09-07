import SwiftUI

@main
struct WallSplitApp: App {
    @StateObject private var viewModel = SplitterViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 960, minHeight: 680)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image…") { viewModel.openFilePicker() }
                    .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("Refresh Screens") {
                    viewModel.screenManager.detectScreens()
                    viewModel.regenerateTiles()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Apply Wallpapers") { viewModel.applyWallpapers() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .disabled(viewModel.tiles.isEmpty)
                Button("Export to Folder…") { viewModel.exportTiles() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(viewModel.tiles.isEmpty)
                Divider()
                Button("Save Preset…") { viewModel.openSavePresetSheet() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(viewModel.sourceImage == nil)
            }

            CommandGroup(replacing: .help) {
                Button("WallSplit Help") { viewModel.showHelp = true }
                    .keyboardShortcut("?", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
