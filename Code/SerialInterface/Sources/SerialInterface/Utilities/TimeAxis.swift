struct TimeAxis {
  nonisolated(unsafe)
  static var shortLength: Double = -1
  static var shortMajorTick: Double { shortLength / 5 }
  
  nonisolated(unsafe)
  static var longLength: Double = -1
  static var longMajorTick: Double { longLength / 5 }
}
