import AVFoundation
import Foundation
import Vision

/// Mede quanto a cabeça virou usando a webcam e o framework Vision.
/// `onYaw` recebe o ângulo bruto em graus (nil quando não há rosto) a cada quadro, em uma fila de fundo.
public final class HeadTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "anyspace.head")
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
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)
        try? handler.perform([request])

        // Com vários rostos, usa o maior (o mais perto da câmera).
        let face = request.results?.max { $0.boundingBox.width < $1.boundingBox.width }
        if let yaw = face?.yaw?.floatValue {
            onYaw(sign * yaw * 180 / .pi)
        } else {
            onYaw(nil)
        }
    }
}
