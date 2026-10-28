import Foundation
import Network

/// Formato do pacote (UDP, rede local): "ANYS" · versão(1) · sequência(4) · senha(4) · quadros(2) · PCM int16 estéreo intercalado.
/// Não é criptografado: a senha só evita que qualquer aparelho da rede injete áudio sem querer.
public enum AudioPacket {
    public static let headerSize = 15
    public static let framesPerPacket = 480

    public static func passwordHash(_ text: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for byte in text.utf8 { h = (h ^ UInt32(byte)) &* 16777619 }
        return h
    }

    public static func encode(sequence: UInt32, password: String, left: [Float], right: [Float]) -> Data {
        let frames = min(left.count, right.count)
        var data = Data("ANYS".utf8)
        data.append(1)
        for value in [sequence, passwordHash(password)] {
            withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
        }
        withUnsafeBytes(of: UInt16(frames).bigEndian) { data.append(contentsOf: $0) }
        for i in 0..<frames {
            for sample in [left[i], right[i]] {
                let clipped = Int16(max(-1, min(1, sample)) * 32767)
                withUnsafeBytes(of: clipped.littleEndian) { data.append(contentsOf: $0) }
            }
        }
        return data
    }

    /// Devolve nil se o pacote for inválido ou a senha estiver errada.
    public static func decode(_ data: Data, password: String) -> (sequence: UInt32, left: [Float], right: [Float])? {
        let bytes = [UInt8](data)
        guard bytes.count >= headerSize, Array(bytes[0..<4]) == Array("ANYS".utf8), bytes[4] == 1 else { return nil }
        func u32(_ at: Int) -> UInt32 { bytes[at..<at + 4].reduce(0) { $0 << 8 | UInt32($1) } }
        let frames = Int(UInt16(bytes[13]) << 8 | UInt16(bytes[14]))
        guard u32(9) == passwordHash(password), bytes.count == headerSize + frames * 4 else { return nil }
        var left = [Float](repeating: 0, count: frames), right = left
        for i in 0..<frames {
            let o = headerSize + i * 4
            left[i] = Float(Int16(bitPattern: UInt16(bytes[o]) | UInt16(bytes[o + 1]) << 8)) / 32767
            right[i] = Float(Int16(bitPattern: UInt16(bytes[o + 2]) | UInt16(bytes[o + 3]) << 8)) / 32767
        }
        return (u32(5), left, right)
    }
}

/// Recebe áudio de outro dispositivo e o escreve nos buffers de uma fonte.
public final class UDPAudioReceiver {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "anyspace.udp.receive")
    private let password: String
    private let left: MonoRingBuffer
    private let right: MonoRingBuffer
    public private(set) var packetsAccepted = 0
    public private(set) var packetsRejected = 0

    public init(port: UInt16, password: String, left: MonoRingBuffer, right: MonoRingBuffer) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw NSError(domain: "anyspace", code: 1) }
        listener = try NWListener(using: .udp, on: nwPort)
        self.password = password
        self.left = left
        self.right = right
    }

    public func start(onReady: (() -> Void)? = nil) {
        listener.stateUpdateHandler = { state in if case .ready = state { onReady?() } }
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.queue ?? .main)
            self?.receive(on: connection)
        }
        listener.start(queue: queue)
    }

    public func stop() { listener.cancel() }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data {
                if let packet = AudioPacket.decode(data, password: self.password) {
                    self.packetsAccepted += 1
                    packet.left.withUnsafeBufferPointer { self.left.write($0.baseAddress!, count: packet.left.count) }
                    packet.right.withUnsafeBufferPointer { self.right.write($0.baseAddress!, count: packet.right.count) }
                } else {
                    self.packetsRejected += 1
                }
            }
            if error == nil { self.receive(on: connection) } else { connection.cancel() }
        }
    }
}

/// Envia áudio estéreo a cada 10 ms lendo de dois buffers.
public final class UDPAudioSender {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "anyspace.udp.send")
    private let password: String
    private let left: MonoRingBuffer
    private let right: MonoRingBuffer
    private var timer: DispatchSourceTimer?
    private var sequence: UInt32 = 0

    public init(host: String, port: UInt16, password: String, left: MonoRingBuffer, right: MonoRingBuffer) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .udp)
        self.password = password
        self.left = left
        self.right = right
    }

    public func start() {
        connection.start(queue: queue)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(10))
        timer.setEventHandler { [weak self] in self?.sendNext() }
        timer.resume()
        self.timer = timer
    }

    public func stop() {
        timer?.cancel()
        connection.cancel()
    }

    private func sendNext() {
        let n = AudioPacket.framesPerPacket
        var l = [Float](repeating: 0, count: n), r = l
        l.withUnsafeMutableBufferPointer { left.read(into: $0.baseAddress!, count: n) }
        r.withUnsafeMutableBufferPointer { right.read(into: $0.baseAddress!, count: n) }
        sequence &+= 1
        connection.send(content: AudioPacket.encode(sequence: sequence, password: password, left: l, right: r),
                        completion: .idempotent)
    }
}
