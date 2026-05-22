extension History {
  struct Output {
    var shortTimeData: [TimedSample] = []
    var longTimeData: [TimedAverage] = []
    var trace: TriggerEventTrace?
  }
  
  struct TriggerEventTrace {
    var data: [TimedSample]
    var timeInterval: SIMD2<Double>
    var trigger: Trigger
  }
  
  func output(
    shortInterval: Double,
    longInterval: Double
  ) -> Output {
    var output = Output()
    output.shortTimeData = sampleHistory(time: shortInterval)
    output.longTimeData = averageHistory(time: longInterval)
    
    let trace = triggerEventTrace(bipolarHistoryTime: shortInterval / 2)
    output.trace = trace
    return output
  }
  
  private func sampleHistory(
    time historyTime: Double
  ) -> [TimedSample] {
    guard historyTime >= 0 else {
      fatalError("Invalid time.")
    }
    guard let latestSample else {
      return []
    }
    let earliestTime = latestSample.time - historyTime
    
    var output: [TimedSample] = []
    let endIndex = max(0, sampleCursor - 1)
    let startIndex = max(0, sampleCursor - Self.maxEntryCount)
    for i in (startIndex...endIndex).reversed() {
      let ringIndex = i % Self.maxEntryCount
      let sample = samplesBuffer[ringIndex]
      
      if sample.time >= earliestTime {
        output.append(sample)
      } else {
        break
      }
    }
    
    output.reverse()
    return output
  }
  
  private func averageHistory(
    time historyTime: Double
  ) -> [TimedAverage] {
    guard historyTime >= 0 else {
      fatalError("Invalid time.")
    }
    guard let latestAverage else {
      return []
    }
    let earliestTime = latestAverage.time - historyTime
    
    var output: [TimedAverage] = []
    let endIndex = max(0, averageCursor - 1)
    let startIndex = max(0, averageCursor - self.maxAverageCount)
    for i in (startIndex...endIndex).reversed() {
      let ringIndex = i % self.maxAverageCount
      let average = averagesBuffer[ringIndex]
      
      if average.time >= earliestTime {
        output.append(average)
      } else {
        break
      }
    }
    
    output.reverse()
    return output
  }
  
  private func triggerEventTrace(
    bipolarHistoryTime: Double
  ) -> TriggerEventTrace? {
    func isValid(event: TriggerEvent) -> Bool {
      let minimumStartPoint = sampleCursor - Self.maxEntryCount + 3
      if event.cursor < minimumStartPoint {
        return false
      }
      return true
    }
    let validEvents = triggerEvents.filter(isValid(event:))
    guard validEvents.count > 0 else {
      return nil
    }
    
    func getBestEvent() -> TriggerEvent {
      guard let latestSample else {
        fatalError("This should never happen.")
      }
      let maximumTime = latestSample.time - bipolarHistoryTime
      
      for i in validEvents.indices.reversed() {
        let event = validEvents[i]
        if event.centerTime <= maximumTime {
          return event
        }
      }
      return validEvents.first!
    }
    let bestEvent = getBestEvent()
    
    func getCursorRange() -> Range<Int>? {
      let samplePeriod = Double(Self.logPeriodMicros) * 1e-6
      let bipolarSampleCount = Int(bipolarHistoryTime / samplePeriod)
      
      var minimumCursor = bestEvent.cursor - bipolarSampleCount
      minimumCursor = max(minimumCursor, sampleCursor - Self.maxEntryCount)
      minimumCursor = max(minimumCursor, 0)
      
      var maximumCursor = bestEvent.cursor + bipolarSampleCount
      maximumCursor = min(maximumCursor, sampleCursor)
      
      guard maximumCursor - minimumCursor > 3 else {
        print("Cursor range was too small.")
        print(minimumCursor)
        print(maximumCursor)
        return nil
      }
      return minimumCursor..<maximumCursor
    }
    guard let cursorRange = getCursorRange() else {
      return nil
    }
    
    var outputData: [TimedSample] = []
    for sampleID in cursorRange {
      let ringIndex = sampleID % Self.maxEntryCount
      let sample = samplesBuffer[ringIndex]
      outputData.append(sample)
    }
    
    var outputInterval: SIMD2<Double> = .zero
    outputInterval[0] = bestEvent.centerTime - bipolarHistoryTime
    outputInterval[1] = bestEvent.centerTime + bipolarHistoryTime
    
    return TriggerEventTrace(
      data: outputData,
      timeInterval: outputInterval,
      trigger: bestEvent.trigger)
  }
}
