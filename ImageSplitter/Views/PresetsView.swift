import SwiftUI

struct PresetsView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Presets", systemImage: "star.fill").font(.headline)
                .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            if viewModel.presetManager.presets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star.slash").font(.title2).foregroundStyle(.quaternary)
                    Text("No presets yet").font(.caption).foregroundStyle(.tertiary)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.presetManager.presets) { PresetRow(preset: $0) }
                    }.padding(.vertical, 4)
                }
            }
        }
    }
}

private struct PresetRow: View {
    let preset: Preset
    @EnvironmentObject var viewModel: SplitterViewModel
    @State private var hover = false
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name).font(.callout.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    Label("\(preset.screenCount)", systemImage: "display").font(.caption2)
                    Text("·").font(.caption2)
                    Text(preset.displayDate).font(.caption2)
                }.foregroundStyle(.secondary)
            }
            Spacer()
            if hover {
                Button { viewModel.loadPreset(preset) } label: {
                    Image(systemName: "arrow.down.circle.fill").font(.callout).foregroundStyle(Color.accentColor)
                }.buttonStyle(.borderless)
                Button { viewModel.presetManager.deletePreset(id: preset.id) } label: {
                    Image(systemName: "trash").font(.caption).foregroundStyle(.red.opacity(0.7))
                }.buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(hover ? Color.accentColor.opacity(0.06) : .clear)
        .contentShape(Rectangle()).onHover { hover = $0 }
        .onTapGesture(count: 2) { viewModel.loadPreset(preset) }
    }
}
