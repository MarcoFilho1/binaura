import Synchronization

/// Fila circular para um escritor (thread do tap) e um leitor (thread do motor de áudio), sem travas.
/// Guarda áudio mono. Se o leitor ficar muito para trás, ele pula para perto do presente
/// em vez de acumular atraso.
public final class MonoRingBuffer: @unchecked Sendable {
    private let capacity: Int
    private let mask: Int
    private let storage: UnsafeMutablePointer<Float>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(0)

    /// Acima disso o leitor descarta o excesso (≈ 50 ms a 48 kHz).
    public let maxFill: Int
    /// Quanto sobra depois de descartar (≈ 10 ms a 48 kHz).
    public let targetFill: Int

    public init(capacityPowerOfTwo: Int = 16384, maxFill: Int = 2400, targetFill: Int = 480) {
        precondition(capacityPowerOfTwo & (capacityPowerOfTwo - 1) == 0)
        capacity = capacityPowerOfTwo
        mask = capacityPowerOfTwo - 1
        self.maxFill = maxFill
        self.targetFill = targetFill
        storage = .allocate(capacity: capacityPowerOfTwo)
        storage.initialize(repeating: 0, count: capacityPowerOfTwo)
    }

    deinit { storage.deallocate() }

    public func write(_ samples: UnsafePointer<Float>, count: Int) {
        let w = writeIndex.load(ordering: .relaxed)
        let r = readIndex.load(ordering: .acquiring)
        let n = min(count, capacity - (w - r))
        guard n > 0 else { return }
        for i in 0..<n { storage[(w + i) & mask] = samples[i] }
        writeIndex.store(w + n, ordering: .releasing)
    }

    /// Preenche `out` com `count` amostras. Se faltar áudio, escreve silêncio e não consome nada.
    public func read(into out: UnsafeMutablePointer<Float>, count: Int) {
        let w = writeIndex.load(ordering: .acquiring)
        var r = readIndex.load(ordering: .relaxed)
        if w - r > maxFill {
            r = w - targetFill
            readIndex.store(r, ordering: .releasing)
        }
        guard w - r >= count else {
            out.update(repeating: 0, count: count)
            return
        }
        for i in 0..<count { out[i] = storage[(r + i) & mask] }
        readIndex.store(r + count, ordering: .releasing)
    }
}
