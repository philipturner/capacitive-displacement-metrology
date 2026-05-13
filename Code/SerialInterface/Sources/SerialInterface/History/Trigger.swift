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
    let valueBefore = before.values[channel]
    let valueAfter = after.values[channel]
    
    switch type {
    case .timeInterval(let period, let offset):
      var times = SIMD2<Double>(before.time, after.time)
      times -= offset
      times /= period
      times.round(.down)
      
      if times[0] == times[1] - 1 {
        return true
      } else if times[0] == times[1] {
        return false
      } else {
        fatalError("This should never happen.")
      }
      
    case .level(let threshold):
      if valueBefore == valueAfter {
        return false
      }
      
      func didCrossThreshold() -> Bool {
        if valueBefore == threshold {
          return true
        }
        if valueAfter == threshold {
          return true
        }
        if (valueBefore - threshold) * (valueAfter - threshold) < 0 {
          return true
        }
        return false
      }
      if !didCrossThreshold() {
        return false
      }
      
      let dx = valueAfter - valueBefore
      switch polarity {
      case .positive:
        if dx > 0 {
          return true
        }
      case .negative:
        if dx < 0 {
          return true
        }
      case .signAgnostic:
        return true
      }
      return false
      
    case .derivative(let dx_target, let dt_target):
      guard dx_target > 0 else {
        fatalError("Specify polarity in a separate parameter.")
      }
      guard dt_target != 0 else {
        fatalError("Invalid slope threshold.")
      }
      let targetSlope = abs(dx_target / dt_target)
      
      let dx = valueAfter - valueBefore
      let dt = Float(after.time - before.time)
      let slope = dx / dt
      if abs(slope) < targetSlope {
        return false
      }
      
      switch polarity {
      case .positive:
        if slope > 0 {
          return true
        }
      case .negative:
        if slope < 0 {
          return true
        }
      case .signAgnostic:
        return true
      }
      return false
    }
  }
}
