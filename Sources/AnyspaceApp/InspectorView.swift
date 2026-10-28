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
            profilesSection
            networkSection
            generalSection
        }
        .formStyle(.grouped)
    }

    // MARK: fontes

    private var sourcesSection: some View {
        Section {
            ForEach(model.scene.all) { source in
                let selected = source.id == model.selectedID
                HStack(spacing: Space.m) {
                    SourceIconView(id: source.id, size: 24)
                    Text(source.name).lineLimit(1)
                    Spacer()
                    Button { model.update(source.id) { $0.muted.toggle() } } label: {
                        Image(systemName: source.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(source.muted ? Color.secondary : Color.primary)
                            .frame(width: 20)
                    }
                    .buttonStyle(.borderless)
                    .help(source.muted ? "Reativar o som" : "Silenciar")
                    .accessibilityLabel(source.muted ? "Reativar \(source.name)" : "Silenciar \(source.name)")
                }
                .contentShape(Rectangle())
                .onTapGesture { model.selectedID = source.id }
                .listRowBackground(selected ? Color.accentColor.opacity(0.16) : Color.clear)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
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
        Section(source.name) {
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
            .help("0° é à frente, 90° à direita, -90° à esquerda e 180° atrás.")
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
        }
    }

    // MARK: cabeça

    private var headSection: some View {
        Section {
            Toggle("Acompanhar a cabeça", isOn: $model.scene.headTracking)
            if model.scene.headTracking {
                Picker("Câmera", selection: $model.scene.cameraName) {
                    Text("Do Mac (padrão)").tag("")
                    ForEach(model.cameras, id: \.self) { Text($0).tag($0) }
                }
                LabeledContent("Ângulo") {
                    Text(String(format: "%+.0f°", model.headAngle)).monospacedDigit()
                }
                LabeledContent("Estado") {
                    Text(model.headStatus).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                }
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
                    Slider(value: $model.scene.width, in: 0...60).frame(width: 110).labelsHidden()
                    Text("\(Int(model.scene.width))°").monospacedDigit().frame(width: 34, alignment: .trailing)
                }
            }
            Toggle("Reverberação de sala", isOn: $model.scene.reverbOn)
            if model.scene.reverbOn {
                LabeledContent("Intensidade") {
                    Slider(value: $model.scene.reverbDB, in: -40...0).frame(width: 140).labelsHidden()
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

    // MARK: perfis

    private var profilesSection: some View {
        Section {
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
        } header: {
            Text("Perfis")
        } footer: {
            Text("Guarda posições, volumes, abertura, reverberação e filtro. Um nome que já existe é substituído.")
        }
    }

    private func saveProfile() {
        model.saveProfile(newProfileName)
        newProfileName = ""
    }

    // MARK: rede

    private var networkSection: some View {
        Section {
            DisclosureGroup("Outro dispositivo (rede local)", isExpanded: $showNetwork) {
                SecureField("Senha", text: $model.scene.networkPassword)
                HStack {
                    TextField("Porta", text: $networkPort).frame(width: 70)
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

    private var generalSection: some View {
        Section {
            Toggle("Abrir ao iniciar o Mac", isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchAtLogin($0) }))
        }
    }
}
