import SwiftUI

/// Toca um chiado em uma de 3 posições e você diz de onde veio. Serve para comparar filtros e ajustes.
struct BlindTestView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var positions: [(name: String, symbol: String, angle: Float)] {
        [(String(localized: "Esquerda"), "arrow.left", -60), (String(localized: "Frente"), "arrow.up", 0), (String(localized: "Direita"), "arrow.right", 60)]
    }
    private let totalRounds = 12

    @State private var target: Int?
    @State private var canAnswer = false
    @State private var rounds = 0
    @State private var correct = 0
    @State private var confusion = [[Int]](repeating: [0, 0, 0], count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Teste cego").font(.title2.weight(.semibold))
                Text("Filtro atual: \(filterName). O resto do som fica mudo durante o teste. Use fones.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if rounds >= totalRounds {
                results
            } else {
                ProgressView(value: Double(rounds), total: Double(totalRounds)) {
                    Text("Rodada \(rounds + 1) de \(totalRounds)").font(.callout)
                }
                HStack {
                    Spacer()
                    Button { play() } label: {
                        Label(LocalizedStringKey(target == nil ? "Tocar" : "Tocar de novo"), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    Spacer()
                }
                Text("De onde veio o som?").font(.headline)
                HStack(spacing: Space.m) {
                    ForEach(0..<3, id: \.self) { i in
                        Button { answer(i) } label: {
                            Label(positions[i].name, systemImage: positions[i].symbol).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).controlSize(.large).disabled(!canAnswer)
                    }
                }
            }

            HStack {
                Spacer()
                Button(LocalizedStringKey(rounds >= totalRounds ? "Concluir" : "Fechar")) { model.session.endTest(); dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Space.xl)
        .frame(width: 460)
        .onDisappear { model.session.endTest() }
    }

    private var filterName: String {
        switch model.scene.algorithm {
        case "HRTF": String(localized: "HRTF")
        case "sphericalHead": String(localized: "cabeça esférica")
        case "equalPowerPanning": String(localized: "só pan")
        default: String(localized: "HRTF (alta qualidade)")
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Acertos: \(correct) de \(totalRounds)").font(.title3.weight(.semibold))
            Grid(alignment: .trailing, horizontalSpacing: Space.l, verticalSpacing: Space.s) {
                GridRow {
                    Text("")
                    ForEach(positions, id: \.name) { Text("ouvi \($0.name.lowercased())").font(.caption).foregroundStyle(.secondary) }
                }
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        Text("era \(positions[row].name.lowercased())").font(.caption).foregroundStyle(.secondary)
                        ForEach(0..<3, id: \.self) { col in
                            Text("\(confusion[row][col])").monospacedDigit()
                                .fontWeight(row == col ? .semibold : .regular)
                                .foregroundStyle(row == col ? Color.primary : Color.secondary)
                        }
                    }
                }
            }
            Button("Repetir") { rounds = 0; correct = 0; confusion = [[Int]](repeating: [0, 0, 0], count: 3) }
        }
    }

    private func play() {
        if target == nil { target = Int.random(in: 0..<3) }
        model.session.playBurst(angle: positions[target!].angle)
        canAnswer = true
    }

    private func answer(_ guess: Int) {
        guard let t = target else { return }
        confusion[t][guess] += 1
        if guess == t { correct += 1 }
        rounds += 1
        target = nil
        canAnswer = false
        if rounds >= totalRounds { model.session.endTest() }
    }
}
