import SwiftUI

/// Toca um chiado em uma de 3 posições e você diz de onde veio. Serve para comparar filtros e ajustes.
struct BlindTestView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private let positions: [(name: String, angle: Float)] = [("Esquerda", -60), ("Frente", 0), ("Direita", 60)]
    private let totalRounds = 12

    @State private var target: Int?
    @State private var canAnswer = false
    @State private var rounds = 0
    @State private var correct = 0
    @State private var confusion = [[Int]](repeating: [0, 0, 0], count: 3)

    var body: some View {
        VStack(spacing: 14) {
            Text("Teste cego").font(.title2)
            Text("Filtro atual: \(model.scene.algorithm). O resto do som fica mudo durante o teste.")
                .font(.caption).foregroundStyle(.secondary)

            if rounds >= totalRounds {
                Text("Acertos: \(correct) de \(totalRounds)").font(.title3)
                Grid {
                    GridRow {
                        Text("")
                        ForEach(positions, id: \.name) { Text("ouvi \($0.name)").font(.caption) }
                    }
                    ForEach(0..<3, id: \.self) { row in
                        GridRow {
                            Text("era \(positions[row].name)").font(.caption)
                            ForEach(0..<3, id: \.self) { Text("\(confusion[row][$0])").monospacedDigit() }
                        }
                    }
                }
                Button("Repetir") { rounds = 0; correct = 0; confusion = [[Int]](repeating: [0, 0, 0], count: 3) }
            } else {
                Text("Rodada \(rounds + 1) de \(totalRounds)")
                Button(target == nil ? "Tocar" : "Tocar de novo") { play() }
                HStack {
                    ForEach(0..<3, id: \.self) { i in
                        Button(positions[i].name) { answer(i) }.disabled(!canAnswer)
                    }
                }
            }
            Button("Fechar") { model.session.endTest(); dismiss() }
        }
        .padding(24)
        .frame(minWidth: 420)
        .onDisappear { model.session.endTest() }
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
