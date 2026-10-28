import AnyspaceCore
import SwiftUI

struct ControlsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showBlindTest = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                sourcesSection
                headSection
                soundSection
                Button("Teste cego: de onde vem o som?") { showBlindTest = true }
                    .disabled(!model.effectOn)
                if let message = model.message {
                    Text(message).font(.caption).foregroundStyle(.red)
                        .onTapGesture { model.message = nil }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showBlindTest) { BlindTestView().environmentObject(model) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Efeito espacial ligado", isOn: Binding(get: { model.effectOn }, set: { model.setEffect($0) }))
                .toggleStyle(.switch).font(.headline)
            Text(model.effectOn ? "Saída: \(model.session.outputName)"
                                : "Desligado: o som do Mac sai normalmente.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func binding(_ id: String) -> Binding<SourceSetting> {
        Binding(
            get: { model.scene.all.first { $0.id == id } ?? SourceSetting(id: id, name: id) },
            set: { model.scene.update($0) }
        )
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fontes").font(.headline)
            ForEach(model.scene.all) { source in
                let b = binding(source.id)
                HStack {
                    Button { b.wrappedValue.muted.toggle() } label: {
                        Image(systemName: b.wrappedValue.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }.buttonStyle(.borderless)
                    Text(source.name).frame(width: 110, alignment: .leading).lineLimit(1)
                    Slider(value: b.volume, in: 0...1)
                    if source.id != SoundScene.restID {
                        Button { model.removeApp(source.id) } label: { Image(systemName: "xmark.circle") }
                            .buttonStyle(.borderless)
                    }
                }
            }
            let candidates = model.availableApps.filter { app in !model.scene.apps.contains { $0.id == app.id } }
            Menu("Adicionar app ao mapa") {
                if candidates.isEmpty { Text("Nenhum app com áudio aberto") }
                ForEach(candidates) { app in
                    Button(app.isPlaying ? "▶︎ \(app.name)" : app.name) { model.addApp(app) }
                }
            }
            Text("Apps fora do mapa continuam no “Resto do sistema”. Arraste as bolinhas para mudar a posição.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var headSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cabeça (webcam)").font(.headline)
            Toggle("Acompanhar a cabeça", isOn: $model.scene.headTracking)
            Picker("Câmera", selection: $model.scene.cameraName) {
                Text("Do Mac (padrão)").tag("")
                ForEach(model.cameras, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Inverter o sentido", isOn: $model.scene.invertHead)
            HStack {
                Button("Calibrar centro") { model.calibrate() }
                Text(model.headStatus).font(.caption).foregroundStyle(.secondary)
            }
            Text("Vire para a direita: o som parado à sua frente deve passar para o ouvido esquerdo. Se estiver ao contrário, marque “Inverter”. A câmera só fica ligada enquanto há som tocando.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Som").font(.headline)
            HStack {
                Text("Abertura do estéreo")
                Slider(value: $model.scene.width, in: 0...60)
                Text("\(Int(model.scene.width))°").monospacedDigit().frame(width: 40)
            }
            Toggle("Reverberação de sala", isOn: $model.scene.reverbOn)
            if model.scene.reverbOn {
                HStack {
                    Text("Intensidade")
                    Slider(value: $model.scene.reverbDB, in: -40...0)
                }
            }
            Picker("Filtro de direção", selection: $model.scene.algorithm) {
                Text("HRTF alta qualidade").tag("HRTFHQ")
                Text("HRTF").tag("HRTF")
                Text("Cabeça esférica").tag("sphericalHead")
                Text("Só pan (sem HRTF)").tag("equalPowerPanning")
            }
            Toggle("Abrir ao iniciar o Mac", isOn: Binding(get: { model.launchesAtLogin },
                                                           set: { model.setLaunchAtLogin($0) }))
        }
    }
}
