import CoreGraphics
import Foundation

/// Triangulação de Delaunay (Bowyer-Watson). Devolve triângulos como trios de índices de `points`.
public func delaunayTriangles(_ points: [CGPoint]) -> [[Int]] {
    let n = points.count
    guard n >= 3 else { return [] }
    let xs = points.map(\.x), ys = points.map(\.y)
    let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
    let span = max(maxX - minX, maxY - minY, 1e-6)
    let midX = (minX + maxX) / 2, midY = (minY + maxY) / 2
    // Triângulo gigante que contém todos os pontos; seus vértices são descartados no fim.
    let all = points + [CGPoint(x: midX - 1000 * span, y: midY - span),
                        CGPoint(x: midX, y: midY + 1000 * span),
                        CGPoint(x: midX + 1000 * span, y: midY - span)]

    struct Tri { var a: Int, b: Int, c: Int, cx: CGFloat, cy: CGFloat, r2: CGFloat }
    func make(_ a: Int, _ b: Int, _ c: Int) -> Tri {
        let p = all[a], q = all[b], r = all[c]
        let d = 2 * (p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y))
        guard abs(d) > 1e-18 else { return Tri(a: a, b: b, c: c, cx: 0, cy: 0, r2: .infinity) }
        let p2 = p.x * p.x + p.y * p.y, q2 = q.x * q.x + q.y * q.y, r2 = r.x * r.x + r.y * r.y
        let ux = (p2 * (q.y - r.y) + q2 * (r.y - p.y) + r2 * (p.y - q.y)) / d
        let uy = (p2 * (r.x - q.x) + q2 * (p.x - r.x) + r2 * (q.x - p.x)) / d
        return Tri(a: a, b: b, c: c, cx: ux, cy: uy, r2: (p.x - ux) * (p.x - ux) + (p.y - uy) * (p.y - uy))
    }

    var triangles = [make(n, n + 1, n + 2)]
    for i in 0..<n {
        let p = all[i]
        var bad: [Tri] = [], keep: [Tri] = []
        for t in triangles {
            let dx = p.x - t.cx, dy = p.y - t.cy
            if dx * dx + dy * dy < t.r2 { bad.append(t) } else { keep.append(t) }
        }
        // Arestas que aparecem uma única vez entre os triângulos removidos formam o contorno do "buraco".
        var edgeCount: [[Int]: Int] = [:]
        for t in bad {
            for (u, v) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)] { edgeCount[[min(u, v), max(u, v)], default: 0] += 1 }
        }
        triangles = keep
        for (edge, count) in edgeCount where count == 1 { triangles.append(make(edge[0], edge[1], i)) }
    }
    return triangles.filter { $0.a < n && $0.b < n && $0.c < n }.map { [$0.a, $0.b, $0.c] }
}

/// Escolhe ~37 pontos-chave do rosto (em ordem fixa, para os índices da malha não mudarem de um quadro para outro):
/// maxilar, sobrancelhas, olhos, pupilas, nariz, boca, queixo e três pontos estimados na testa.
/// Devolve nil se faltar alguma região essencial.
public func buildFaceMesh(contour: [CGPoint], leftBrow: [CGPoint], rightBrow: [CGPoint],
                          leftEye: [CGPoint], rightEye: [CGPoint], noseCrest: [CGPoint], nose: [CGPoint],
                          lips: [CGPoint], median: [CGPoint], pupils: [CGPoint]) -> [CGPoint]? {
    guard contour.count >= 5, leftBrow.count >= 2, rightBrow.count >= 2, leftEye.count >= 4, rightEye.count >= 4,
          noseCrest.count >= 2, nose.count >= 3, lips.count >= 4 else { return nil }

    func even(_ pts: [CGPoint], _ count: Int) -> [CGPoint] {
        (0..<count).map { pts[Int((Double($0) * Double(pts.count - 1) / Double(count - 1)).rounded())] }
    }
    func extremes(_ pts: [CGPoint]) -> [CGPoint] {   // esquerda, direita, topo, base (y cresce para cima)
        [pts.min { $0.x < $1.x }!, pts.max { $0.x < $1.x }!, pts.max { $0.y < $1.y }!, pts.min { $0.y < $1.y }!]
    }

    var mesh: [CGPoint] = []
    mesh += even(contour, 9)
    mesh += even(leftBrow, 3) + even(rightBrow, 3)
    mesh += extremes(leftEye) + extremes(rightEye)
    mesh += pupils.count == 2 ? pupils : [centroid(leftEye), centroid(rightEye)]
    mesh += [noseCrest.max { $0.y < $1.y }!, noseCrest.min { $0.y < $1.y }!]
    mesh += [nose.min { $0.x < $1.x }!, nose.max { $0.x < $1.x }!]
    mesh += extremes(lips)
    mesh.append((median.min { $0.y < $1.y } ?? contour.min { $0.y < $1.y }!))

    // Testa: o Vision não a mede. Estimamos três pontos acima das sobrancelhas, com a altura proporcional ao rosto.
    let brows = leftBrow + rightBrow
    let browTop = brows.map(\.y).max()!, left = brows.map(\.x).min()!, right = brows.map(\.x).max()!
    let faceHeight = contour.map(\.y).max()! - contour.map(\.y).min()!
    let foreheadY = browTop + 0.22 * faceHeight
    for t in [0.2, 0.5, 0.8] { mesh.append(CGPoint(x: left + (right - left) * t, y: foreheadY)) }
    return mesh
}

private func centroid(_ pts: [CGPoint]) -> CGPoint {
    CGPoint(x: pts.map(\.x).reduce(0, +) / CGFloat(pts.count), y: pts.map(\.y).reduce(0, +) / CGFloat(pts.count))
}

/// Remove triângulos esticados demais (ligam pontos que não são vizinhos de verdade, como queixo e testa).
public func prunedTriangles(_ triangles: [[Int]], points: [CGPoint], maxEdge: CGFloat) -> [[Int]] {
    triangles.filter { t in
        [(0, 1), (1, 2), (2, 0)].allSatisfy { (u, v) in
            hypot(points[t[u]].x - points[t[v]].x, points[t[u]].y - points[t[v]].y) <= maxEdge
        }
    }
}
