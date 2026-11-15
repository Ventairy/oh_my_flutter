import Foundation

internal struct IOSDisintegrateGeometry {
  internal let columns: Int
  internal let rows: Int
  internal let particleCount: Int
  internal let maximumCellWidth: Double
  internal let maximumCellHeight: Double
  internal let attributes: [Float]

  internal init(configuration: IOSDisintegrateConfiguration) {
    let width = Double(configuration.width)
    let height = Double(configuration.height)
    let cellSize = max(
      configuration.minimumCellSize,
      sqrt(width * height / Double(configuration.maximumParticleCount))
    )
    columns = min(configuration.maximumParticleCount, Int(ceil(width / cellSize)))
    rows = min(Int(ceil(height / cellSize)), configuration.maximumParticleCount / columns)
    particleCount = columns * rows
    maximumCellWidth = width / Double(columns) + Double(Float(width).ulp)
    maximumCellHeight = height / Double(rows) + Double(Float(height).ulp)
    let cellWidth = width / Double(columns)
    let cellHeight = height / Double(rows)
    let motion = configuration.geometryParameters
    let columnDelayStep = motion[0] / Double(columns)
    var randomState = configuration.seed
    var attributes = [Float](repeating: 0, count: particleCount * 10)
    for row in 0..<rows {
      for column in 0..<columns {
        let offset = (row * columns + column) * 10
        attributes[offset] = Float(Double(column) * cellWidth)
        attributes[offset + 1] = Float(Double(row) * cellHeight)
        attributes[offset + 2] = Float(Double(column + 1) * cellWidth)
        attributes[offset + 3] = Float(Double(row + 1) * cellHeight)
        let delay = Double(column) * columnDelayStep + Self.nextUniform(&randomState) * motion[1]
        attributes[offset + 4] = Float(delay)
        attributes[offset + 5] = Float(
          motion[2] + Self.nextUniform(&randomState) * (motion[3] - delay)
        )
        attributes[offset + 6] = Float(
          -width * (motion[4] + Self.nextUniform(&randomState) * motion[5])
        )
        attributes[offset + 7] = Float(
          -width * (motion[6] + Self.nextUniform(&randomState) * motion[7])
        )
        attributes[offset + 8] = Float(Self.nextUniform(&randomState) * 6.283185307179586476925286766559)
        attributes[offset + 9] = Float(
          width * (motion[8] + Self.nextUniform(&randomState) * motion[9])
        )
      }
    }
    self.attributes = attributes
  }

  private static func nextUniform(_ state: inout UInt32) -> Double {
    state ^= state << 13
    state ^= state >> 17
    state ^= state << 5
    return Double(state) * (1.0 / 4294967296.0)
  }
}
