import AVFoundation
import Foundation
import Vision

/// Mede quanto a cabeça virou usando a webcam e o framework Vision.
/// `onYaw` recebe o ângulo bruto em graus (nil quando não há rosto) a cada quadro, em uma fila de fundo.
public final class HeadTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let boxLock = NSLock()
    private var box: CGRect?
    private var currentDetail: FaceDetail?
    private var landmarks = false

    /// Para mostrar a imagem da câmera na janela de depuração.
    public var previewSession: AVCaptureSession { session }
    /// Retângulo do rosto (0...1, origem embaixo à esquerda, imagem sem espelhar), ou nil.
    public var faceBox: CGRect? { boxLock.lock(); defer { boxLock.unlock() }; return box }
    /// Pontos do rosto e olhar estimado (só quando a janela de depuração está aberta, porque custa mais processador).
    public var faceDetail: FaceDetail? { boxLock.lock(); defer { boxLock.unlock() }; return currentDetail }
    public func setLandmarks(_ on: Bool) { boxLock.lock(); landmarks = on; if !on { currentDetail = nil }; boxLock.unlock() }

    /// Estado da permissão de câmera, para a interface explicar o problema antes de tentar ligar.
    public static var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }

    /// Chamado a cada quadro quando os pontos do rosto estão ligados (nil = sem rosto). Usado no diagnóstico.
    public var onDetail: ((FaceDetail?) -> Void)?

    private let queue = DispatchQueue(label: "binaura.head")
    private let onYaw: (Float?) -> Void
    private let sign: Float

    /// `invert` troca o sentido do ângulo, caso a câmera entregue a imagem espelhada.
    public init(invert: Bool, onYaw: @escaping (Float?) -> Void) {
        self.sign = invert ? -1 : 1
        self.onYaw = onYaw
    }

    public static func cameras() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video, position: .unspecified
        ).devices
    }

    public func start(cameraNameContains name: String?, fps: Double = 20, completion: @escaping (String?) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return completion("permissão de câmera negada (Ajustes > Privacidade > Câmera)") }
            let devices = Self.cameras()
            let device = name.flatMap { n in devices.first { $0.localizedName.localizedCaseInsensitiveContains(n) } }
                ?? devices.first { $0.deviceType == .builtInWideAngleCamera }
                ?? devices.first
            guard let device, let input = try? AVCaptureDeviceInput(device: device) else {
                return completion("nenhuma câmera encontrada: \(devices.map(\.localizedName))")
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .vga640x480
            if self.session.canAddInput(input) { self.session.addInput(input) }
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.queue)
            if self.session.canAddOutput(output) { self.session.addOutput(output) }
            self.session.commitConfiguration()

            if (try? device.lockForConfiguration()) != nil {
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                device.unlockForConfiguration()
            }
            self.session.startRunning()
            completion(nil)
        }
    }

    public func stop() { session.stopRunning() }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        boxLock.lock(); let wantLandmarks = landmarks; boxLock.unlock()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)

        // Sempre com pontos do rosto: o yaw do Vision só tem 3 valores (0°, ±45°, ±90°) e causa "pulos".
        // O ângulo usado no som vem da geometria dos pontos (ver YawEstimator).
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        try? handler.perform([request])
        // Com vários rostos, usa o maior (o mais perto da câmera).
        let face = request.results?.max { $0.boundingBox.width < $1.boundingBox.width }

        let detail = face.flatMap { makeDetail($0) }
        boxLock.lock()
        box = face?.boundingBox
        currentDetail = wantLandmarks ? detail : nil   // contornos só para a janela de depuração
        boxLock.unlock()
        if wantLandmarks { onDetail?(detail) }
        onYaw(detail?.yaw)
    }

    private func makeDetail(_ face: VNFaceObservation) -> FaceDetail? {
        guard let yawRad = face.yaw?.floatValue else { return nil }
        let box = face.boundingBox
        let pitch = face.pitch.map { $0.floatValue * 180 / .pi }
        let roll = face.roll.map { $0.floatValue * 180 / .pi }

        func map(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            region?.normalizedPoints.map { CGPoint(x: box.minX + $0.x * box.width, y: box.minY + $0.y * box.height) } ?? []
        }
        let lm = face.landmarks
        var contours: [FaceDetail.Contour] = []
        for (name, points, closed) in [
            ("contorno", map(lm?.faceContour), false), ("sobrancelha esq", map(lm?.leftEyebrow), false),
            ("sobrancelha dir", map(lm?.rightEyebrow), false), ("olho esq", map(lm?.leftEye), true),
            ("olho dir", map(lm?.rightEye), true), ("nariz", map(lm?.noseCrest), false),
            ("lábios", map(lm?.outerLips), true),
        ] where !points.isEmpty { contours.append(.init(name: name, points: points, closed: closed)) }

        let leftPupil = map(lm?.leftPupil).first, rightPupil = map(lm?.rightPupil).first
        let pupils = [leftPupil, rightPupil].compactMap { $0 }

        // Olhar: a posição da pupila dentro do olho, somada à direção da cabeça.
        func offset(eye: [CGPoint], pupil: CGPoint?) -> (x: Float, y: Float)? {
            guard let pupil, eye.count >= 4 else { return nil }
            let xs = eye.map(\.x), ys = eye.map(\.y)
            let width = (xs.max()! - xs.min()!), height = max(ys.max()! - ys.min()!, width * 0.3)
            guard width > 0 else { return nil }
            return (Float((pupil.x - (xs.max()! + xs.min()!) / 2) / width), Float((pupil.y - (ys.max()! + ys.min()!) / 2) / height))
        }
        let offsets = [offset(eye: map(lm?.leftEye), pupil: leftPupil), offset(eye: map(lm?.rightEye), pupil: rightPupil)].compactMap { $0 }
        var eyeYaw: Float?, eyePitch: Float?   // só a parte do olho (pupila dentro do olho), em graus
        if !offsets.isEmpty {
            let ox = offsets.map(\.x).reduce(0, +) / Float(offsets.count)
            let oy = offsets.map(\.y).reduce(0, +) / Float(offsets.count)
            // Na imagem da câmera (sem espelho) olhar para a direita da pessoa move a pupila para a esquerda da imagem.
            eyeYaw = (-ox) * 50
            eyePitch = oy * 40
        }
        let features = geometryFeatures(lm: lm, map: map)
        let visionYaw = yawRad * 180 / .pi
        let yaw = sign * estimateYaw(fMedian: features["f_median"], fEyes: features["f_eyes"], fallbackDegrees: visionYaw)
        var detail = FaceDetail(box: box, yaw: yaw, pitch: pitch, roll: roll, contours: contours,
                                pupils: pupils, gazeYaw: nil, gazePitch: nil)
        if let eyeYaw, let eyePitch { detail.gazeYaw = yaw + eyeYaw; detail.gazePitch = (pitch ?? 0) + eyePitch }
        detail.rawYawDeg = visionYaw
        detail.features = features
        return detail
    }

    /// Razões que variam de forma contínua com a rotação da cabeça, ao contrário do yaw do Vision.
    private func geometryFeatures(lm: VNFaceLandmarks2D?, map: (VNFaceLandmarkRegion2D?) -> [CGPoint]) -> [String: Float] {
        let contour = map(lm?.faceContour), crest = map(lm?.noseCrest), median = map(lm?.medianLine)
        let left = map(lm?.leftEye), right = map(lm?.rightEye)
        guard let minX = contour.map(\.x).min(), let maxX = contour.map(\.x).max(), maxX > minX,
              let tip = crest.min(by: { $0.y < $1.y }), !left.isEmpty, !right.isEmpty else { return [:] }
        let width = maxX - minX, mid = (minX + maxX) / 2
        func mean(_ pts: [CGPoint]) -> CGFloat { pts.map(\.x).reduce(0, +) / CGFloat(pts.count) }
        let eyeA = min(mean(left), mean(right)), eyeB = max(mean(left), mean(right))   // esquerda e direita da imagem
        let dA = abs(tip.x - eyeA), dB = abs(eyeB - tip.x)
        var f: [String: Float] = [
            "f_nose": Float((tip.x - mid) / width),
            "f_eyes": Float(((eyeA + eyeB) / 2 - mid) / width),
            "f_asym": Float((dA - dB) / max(dA + dB, 0.0001)),
            "faceW": Float(width),
        ]
        if !median.isEmpty { f["f_median"] = Float((mean(median) - mid) / width) }
        return f
    }
}
