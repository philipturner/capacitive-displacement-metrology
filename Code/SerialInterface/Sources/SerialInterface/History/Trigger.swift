enum TriggerType {
  // Detect when the signal crosses a threshold.
  case level(Float)
  
  // Detect when the absolute magnitude of the slope exceeds dx / dt.
  case derivative(dx: Float, dt: Float)
}

enum TriggerPolarity {
  case positive
  case negative
  case signAgnostic
}

struct Trigger {
  var type: TriggerType = .level(0)
  var polarity: TriggerPolarity = .signAgnostic
  var channel: Int = 0
}

extension History {
  func processTrigger(before: TimedSample, after: TimedSample) {
    
  }
}
