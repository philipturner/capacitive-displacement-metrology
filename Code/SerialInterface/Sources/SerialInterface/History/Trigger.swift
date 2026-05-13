enum TriggerType {
  // Detect when the signal crosses a threshold.
  case level(Float)
  
  // Detect when the absolute magnitude of the slope exceeds dx / dt.
  case derivative(dx: Float, dt: Float)
  
  // Report at a repeating time interval.
  case timeInterval(period: Double, offset: Double = .zero)
}

enum TriggerPolarity {
  case positive
  case negative
  case signAgnostic
}

struct Trigger {
  var type: TriggerType = .timeInterval(period: 1)
  var polarity: TriggerPolarity = .signAgnostic
  var channel: Int = 0
  
  func check(
    before: History.TimedSample,
    after: History.TimedSample
  ) -> Bool {
    fatalError("Not implemented.")
  }
}
