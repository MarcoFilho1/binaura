import BinauraCore
import SwiftUI

/// Janela principal: palco à esquerda, inspetor à direita, toolbar unificada.
struct MainWindowView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("didSeeWelcome") private var didSeeWelcome = false
    @State private var showInspector = true
    @State private var showWelcome = false
    @State private var askProfileName = false
    @State private var profileName = ""

    var body: some View {
        StageView()
            .inspector(isPresented: $showInspector) {
                InspectorView().inspectorColumnWidth(min: 300, ideal: 340, max: 440)
            }
            .navigationTitle("Binaura")
            .navigationSubtitle(model.effectOn ? "Ligado · \(model.outputName)" : "Desligado")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Toggle("Efeito espacial", isOn: Binding(get: { model.effectOn }, set: { model.setEffect($0) }))
                        .toggleStyle(.switch)
                        .help("Liga ou desliga o efeito. Desligado, o som do Mac sai normal.")
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        ForEach(model.scene.profiles) { profile in
                            Button { model.applyProfile(profile.name) } label: {
                                if model.activeProfileName == profile.name {
                                    Label(profile.name, systemImage: "checkmark")
                                } else {
                                    Text(profile.name)
                                }
                            }
                        }
                        if !model.scene.profiles.isEmpty { Divider() }
                        Button("Salvar configuração atual…") { askProfileName = true }
                    } label: {
                        Label("Perfis", systemImage: "rectangle.stack")
                    }
                    .help("Perfis salvos")
                    Button { showInspector.toggle() } label: { Label("Inspetor", systemImage: "sidebar.right") }
                        .help(showInspector ? "Esconder o inspetor" : "Mostrar o inspetor")
                }
            }
            .alert("Salvar perfil", isPresented: $askProfileName) {
                TextField("Nome (ex.: Trabalho, Filme)", text: $profileName)
                Button("Salvar") { model.saveProfile(profileName); profileName = "" }
                Button("Cancelar", role: .cancel) { profileName = "" }
            } message: {
                Text("Guarda posições, volumes, abertura, reverberação e filtro.")
            }
            .onAppear { if !didSeeWelcome && !model.isPreview { showWelcome = true } }
            .sheet(isPresented: $showWelcome, onDismiss: { didSeeWelcome = true }) {
                WelcomeView { model.setEffect(true); showWelcome = false }
            }
            .sheet(isPresented: $model.showBlindTest) { BlindTestView().environmentObject(model) }
            .frame(minWidth: 860, minHeight: 560)
    }
}
