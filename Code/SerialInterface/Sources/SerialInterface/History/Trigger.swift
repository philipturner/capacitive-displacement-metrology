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
  
  // If true, returns the center time.
  func check(
    before: History.TimedSample,
    after: History.TimedSample
  ) -> Double? {
    let valueBefore = before.values[channel]
    let valueAfter = after.values[channel]
    
    switch type {
    case .timeInterval(let period, let offset):
      var times = SIMD2<Double>(before.time, after.time)
      times -= offset
      times /= period
      times.round(.down)
      
      if times[0] == times[1] - 1 {
        return times[1]
      } else if times[0] == times[1] {
        return nil
      } else {
        fatalError("This should never happen.")
      }
      
    case .level(let threshold):
      if valueBefore == valueAfter {
        return nil
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
        return nil
      }
      
      func createCenterTime() -> Double {
        let progress = Double(
          (threshold - valueBefore) / (valueAfter - valueBefore))
        
        var output: Double = .zero
        output += (1 - progress) * before.time
        output += progress * after.time
        return output
      }
      let centerTime = createCenterTime()
      
      let dx = valueAfter - valueBefore
      switch polarity {
      case .positive:
        if dx > 0 {
          return centerTime
        }
      case .negative:
        if dx < 0 {
          return centerTime
        }
      case .signAgnostic:
        return centerTime
      }
      return nil
      
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
        return nil
      }
      
      switch polarity {
      case .positive:
        if slope > 0 {
          return before.time
        }
      case .negative:
        if slope < 0 {
          return before.time
        }
      case .signAgnostic:
        return before.time
      }
      return nil
    }
  }
}
