import SwiftUI

struct PresetsView: View {
    @EnvironmentObject var viewModel: SplitterViewModel
    @ObservedObject private var proManager = ProManager.shared
    @State private var customMinutes: String = ""
    @State private var showCustomInterval = false
    @State private var feedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Presets", systemImage: "star.fill").font(.headline)
                .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()

            // Rotation controls
            VStack(spacing: 8) {
                Button {
                    if viewModel.presetManager.presets.isEmpty {
                        feedback = "No presets"
                    } else {
                        viewModel.applyRandomPreset()
                        feedback = "Applied random preset"
                    }
                } label: {
                    Label("Random Preset", systemImage: "shuffle")
                        .font(.callout.weight(.medium)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(viewModel.presetManager.presets.isEmpty)

                // Auto-rotate (Pro)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { viewModel.autoRotatePresetsEnabled },
                            set: { enabled in
                                guard proManager.isPro else {
                                    viewModel.showUpgradeSheet = true
                                    return
                                }
                                if enabled { viewModel.startPresetRotation() }
                                else { viewModel.stopPresetRotation() }
                            }
                        )) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath").font(.caption)
                                Text("Auto-rotate").font(.callout)
                                if !proManager.isPro { ProBadge() }
                            }
                        }
                        .toggleStyle(.switch).controlSize(.small)
                        Spacer()
                    }

                    if viewModel.autoRotatePresetsEnabled && proManager.isPro {
                        HStack(spacing: 6) {
                            Picker("", selection: Binding(
                                get: { showCustomInterval ? TimeInterval(-1) : viewModel.autoRotatePresetsInterval },
                                set: { val in
                                    if val == -1 {
                                        showCustomInterval = true
                                    } else {
                                        showCustomInterval = false
                                        viewModel.updatePresetRotationInterval(val)
                                    }
                                }
                            )) {
                                Text("5 min").tag(TimeInterval(300))
                                Text("15 min").tag(TimeInterval(900))
                                Text("30 min").tag(TimeInterval(1800))
                                Text("1 hour").tag(TimeInterval(3600))
                                Text("3 hours").tag(TimeInterval(10800))
                                Text("Daily").tag(TimeInterval(86400))
                                Text("Custom…").tag(TimeInterval(-1))
                            }
                            .pickerStyle(.menu).controlSize(.small)
                            .frame(maxWidth: .infinity)

                            if showCustomInterval {
                                HStack(spacing: 4) {
                                    TextField("min", text: $customMinutes)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 46)
                                        .onSubmit { applyCustomInterval() }
                                    Text("min").font(.caption).foregroundStyle(.secondary)
                                    Button("OK") { applyCustomInterval() }
                                        .buttonStyle(.bordered).controlSize(.mini)
                                }
                            }
                        }
                    }
                }
                .disabled(viewModel.presetManager.presets.isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            if let msg = feedback {
                Text(msg).font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.bottom, 4)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { feedback = nil }
                    }
            }

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

    private func applyCustomInterval() {
        guard let minutes = Double(customMinutes), minutes > 0 else { return }
        viewModel.updatePresetRotationInterval(minutes * 60)
        showCustomInterval = false
        customMinutes = ""
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
