import AnyspaceCore
import SwiftUI

/// Inspetor à direita: fontes, câmera, som, perfis e rede. Form agrupado, como os Ajustes do Sistema.
struct InspectorView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var newProfileName = ""
    @State private var networkPort = "5004"
    @State private var showNetwork = false

    var body: some View {
        Form {
            sourcesSection
            if let id = model.selectedID, let source = model.source(id) { detailSection(source) }
            headSection
            soundSection
            advancedSection
        }
        .formStyle(.grouped)
    }

    // MARK: fontes

    private var sourcesSection: some View {
        Section {
            ScrollView {
                VStack(spacing: 2) {
                ForEach(model.scene.all) { source in
                    let selected = source.id == model.selectedID
                    HStack(spacing: Space.s) {
                        Button { model.selectedID = source.id } label: {
                            HStack(spacing: Space.m) {
                                SourceIconView(id: source.id, size: 24)
                                Text(source.name).lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityHint("Seleciona a fonte para ajustar")
                        Button { model.update(source.id) { $0.muted.toggle() } } label: {
                            Image(systemName: source.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundStyle(source.muted ? Color.secondary : Color.primary)
                                .frame(width: 20)
                        }
                        .buttonStyle(.borderless)
                        .help(source.muted ? "Reativar o som" : "Silenciar")
                        .accessibilityLabel(source.muted ? "Reativar \(source.name)" : "Silenciar \(source.name)")
                    }
                    .padding(.horizontal, Space.s).padding(.vertical, 2)
                    .background(selected ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                }
            }
            .frame(maxHeight: 220)
            let candidates = model.availableApps.filter { app in !model.scene.apps.contains { $0.id == app.id } }
            Menu {
                if candidates.isEmpty { Text("Nenhum app com áudio aberto") }
                ForEach(candidates) { app in
                    Button { model.addApp(app) } label: {
                        Label(app.name, systemImage: app.isPlaying ? "speaker.wave.2" : "app")
                    }
                }
            } label: {
                Label("Adicionar app ao mapa", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } header: {
            Text("Fontes")
        } footer: {
            Text("Apps fora do mapa continuam no “Resto do sistema”.")
        }
    }

    private func detailSection(_ source: SourceSetting) -> some View {
        Section {
            Slider(value: Binding(get: { source.volume }, set: { v in model.update(source.id) { $0.volume = v } }), in: 0...1) {
                Text("Volume")
            } minimumValueLabel: {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
            LabeledContent("Direção") {
                HStack(spacing: Space.xs) {
                    TextField("Direção", value: Binding(get: { Double(source.angle) }, set: { v in model.update(source.id) { $0.angle = Float(min(max(v, -180), 180)) } }),
                              format: .number.precision(.fractionLength(0)))
                        .multilineTextAlignment(.trailing).frame(width: 52).labelsHidden()
                    Text("°").foregroundStyle(.secondary)
                    Stepper("Direção", value: Binding(get: { Double(source.angle) }, set: { v in model.update(source.id) { $0.angle = Float(min(max(v, -180), 180)) } }),
                            in: -180...180, step: 5).labelsHidden()
                }
            }

            LabeledContent("Distância") {
                HStack(spacing: Space.xs) {
                    TextField("Distância", value: Binding(get: { Double(source.distance) }, set: { v in model.update(source.id) { $0.distance = Float(min(max(v, 0.5), 4)) } }),
                              format: .number.precision(.fractionLength(0...2)))
                        .multilineTextAlignment(.trailing).frame(width: 52).labelsHidden()
                    Text("m").foregroundStyle(.secondary)
                    Stepper("Distância", value: Binding(get: { Double(source.distance) }, set: { v in model.update(source.id) { $0.distance = Float(min(max(v, 0.5), 4)) } }),
                            in: 0.5...4, step: 0.25).labelsHidden()
                }
            }
            if source.id != SoundScene.restID {
                Button("Remover do mapa", role: .destructive) { model.removeApp(source.id) }
            }
        } header: {
            Text(source.name)
        } footer: {
            Text("Direção: 0° é à frente, 90° à direita, -90° à esquerda e 180° atrás. Distância de 0,5 a 4 m.")
        }
    }

    // MARK: cabeça

    private var headSection: some View {
        Section {
            Toggle("Acompanhar a cabeça", isOn: $model.scene.headTracking)
            if model.scene.headTracking && (model.cameraAccess == .denied || model.cameraAccess == .restricted) {
                StatusLabel(text: "Erro: permissão da câmera")
                Button("Abrir Ajustes da câmera…") { NSWorkspace.shared.open(PermissionIssue.camera.settingsURL) }
            }
            if model.scene.headTracking {
                Picker("Câmera", selection: $model.scene.cameraName) {
                    Text("Do Mac (padrão)").tag("")
                    ForEach(model.cameras, id: \.self) { Text($0).tag($0) }
                }
                LabeledContent("Ângulo") {
                    Text(String(format: "%+.0f°", model.headAngle)).monospacedDigit()
                }
                LabeledContent("Estado") { StatusLabel(text: model.headStatus) }
                HStack {
                    Button("Calibrar centro") { model.calibrate() }
                    Button("Câmera de debug…") { openWindow(id: "camera") }
                }
                Toggle("Inverter o sentido", isOn: $model.scene.invertHead)
            }
        } header: {
            Text("Cabeça")
        } footer: {
            Text("Vire para a direita: o som parado à sua frente passa para o ouvido esquerdo. A câmera só fica ligada enquanto há som tocando.")
        }
    }

    // MARK: som

    private var soundSection: some View {
        Section {
            LabeledContent("Abertura do estéreo") {
                HStack {
                    Slider(value: $model.scene.width, in: 0...60) { Text("Abertura do estéreo") }.frame(minWidth: 90, maxWidth: 140)
                    Text("\(Int(model.scene.width))°").monospacedDigit().frame(width: 34, alignment: .trailing)
                }
            }
            Toggle("Reverberação de sala", isOn: $model.scene.reverbOn)
            if model.scene.reverbOn {
                LabeledContent("Intensidade") {
                    Slider(value: $model.scene.reverbDB, in: -40...0) { Text("Intensidade da reverberação") }.frame(minWidth: 90, maxWidth: 160)
                }
            }
            Picker("Filtro de direção", selection: $model.scene.algorithm) {
                Text("HRTF alta qualidade").tag("HRTFHQ")
                Text("HRTF").tag("HRTF")
                Text("Cabeça esférica").tag("sphericalHead")
                Text("Só pan (sem HRTF)").tag("equalPowerPanning")
            }
            Button("Teste cego…") { model.showBlindTest = true }.disabled(!model.effectOn)
        } header: {
            Text("Som")
        } footer: {
            Text(filterNote)
        }
    }

    private var filterNote: String {
        switch model.scene.algorithm {
        case "HRTF": "Imita a cabeça e as orelhas com menos processamento."
        case "sphericalHead": "Trata a cabeça como uma bola lisa: esquerda e direita bem marcadas, frente e trás menos."
        case "equalPowerPanning": "Só muda o volume entre os ouvidos, sem noção de profundidade."
        default: "O mais preciso: imita a cabeça e as orelhas. Usa um pouco mais de processador."
        }
    }

    // MARK: avançado (perfis, rede, abrir no login)

    @State private var showAdvanced = false

    private var advancedSection: some View {
        Section {
            // Botão em vez de DisclosureGroup: o DisclosureGroup só abre ao clicar exatamente na seta.
            Button { withAnimation(.snappy(duration: 0.2)) { showAdvanced.toggle() } } label: {
                HStack {
                    Text("Perfis e avançado")
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showAdvanced ? "expandido" : "recolhido")
            .accessibilityHint("Mostra ou esconde perfis, rede e abrir ao iniciar")
            if showAdvanced {
                profilesBlock
                networkBlock
                Toggle("Abrir ao iniciar o Mac", isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchAtLogin($0) }))
            }
        }
    }

    private var profilesBlock: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Perfis").font(.headline)
            ForEach(model.scene.profiles) { profile in
                HStack {
                    Button { model.applyProfile(profile.name) } label: {
                        HStack {
                            Image(systemName: "checkmark").opacity(model.activeProfileName == profile.name ? 1 : 0)
                                .foregroundStyle(Color.accentColor)
                            Text(profile.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button(role: .destructive) { model.deleteProfile(profile.name) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless).help("Apagar perfil").accessibilityLabel("Apagar perfil \(profile.name)")
                }
            }
            HStack {
                TextField("Nome do perfil", text: $newProfileName).onSubmit(saveProfile)
                Button("Salvar atual", action: saveProfile)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Guarda posições, volumes, abertura, reverberação e filtro. Também no menu Perfis da barra de ferramentas.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func saveProfile() {
        model.saveProfile(newProfileName)
        newProfileName = ""
    }

    private var networkBlock: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Outro dispositivo (rede local)").font(.headline)
            SecureField("Senha", text: $model.scene.networkPassword)
            HStack {
                TextField("Porta", text: $networkPort, prompt: Text("Porta")).frame(width: 70)
                    .accessibilityLabel("Porta de rede")
                Button("Receber áudio nessa porta") {
                    if let port = UInt16(networkPort) { model.addNetworkSource(port: port) }
                }
                .disabled(model.scene.networkPassword.isEmpty || UInt16(networkPort) == nil)
            }
            Text("No outro Mac: AnyspaceCLI --send IP:PORTA --password SENHA. Sem criptografia: use só em rede de confiança.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
