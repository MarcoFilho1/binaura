import Foundation

/// Webcam → ângulo bruto → filtro → ângulo suave. Os 2 primeiros segundos definem o centro.
public final class HeadController {
    public struct Stats { public var raw: Float?; public var filtered: Float; public var faces: Int; public var frames: Int }

    private let lock = NSLock()
    private var filter = HeadFilter()
    private var lastFrame = Date()
    private var calibratingUntil = Date.distantPast
    private var raw: Float?
    private var faces = 0, frames = 0
    private var tracker: HeadTracker?
    private let onAngle: (Float) -> Void

    public var isRunning: Bool { tracker != nil }

    public init(onAngle: @escaping (Float) -> Void) { self.onAngle = onAngle }

    public func start(cameraName: String?, invert: Bool, completion: @escaping (String?) -> Void) {
        guard tracker == nil else { return completion(nil) }
        lock.lock()
        filter = HeadFilter()
        lastFrame = Date()
        calibratingUntil = Date().addingTimeInterval(2)
        lock.unlock()
        let tracker = HeadTracker(invert: invert) { [weak self] yaw in self?.handle(yaw) }
        self.tracker = tracker
        tracker.start(cameraNameContains: cameraName?.isEmpty == false ? cameraName : nil) { [weak self] error in
            if error != nil { self?.tracker = nil }
            completion(error)
        }
    }

    public func stop() {
        tracker?.stop()
        tracker = nil
        onAngle(0)
    }

    public func calibrate() {
        lock.lock(); filter.calibrate(); lock.unlock()
    }

    public func takeStats() -> Stats {
        lock.lock(); defer { lock.unlock() }
        let s = Stats(raw: raw, filtered: filter.output, faces: faces, frames: frames)
        faces = 0; frames = 0
        return s
    }

    private func handle(_ yaw: Float?) {
        lock.lock()
        let now = Date()
        let dt = Float(min(now.timeIntervalSince(lastFrame), 0.5))
        lastFrame = now
        raw = yaw
        frames += 1
        if yaw != nil { faces += 1 }
        let angle = filter.update(raw: yaw, dt: dt)
        if now < calibratingUntil { filter.calibrate() }
        lock.unlock()
        onAngle(angle)
    }
}
