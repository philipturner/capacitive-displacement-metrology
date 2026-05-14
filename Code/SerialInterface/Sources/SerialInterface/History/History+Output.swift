extension History {
  struct Output {
    var shortTimeData: [TimedSample] = []
    var longTimeData: [TimedAverage] = []
    var trace: (data: [TimedSample], timeInterval: SIMD2<Double>)?
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
    let startIndex = max(0, averageCursor - Self.maxAverageCount)
    for i in (startIndex...endIndex).reversed() {
      let ringIndex = i % Self.maxAverageCount
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
  ) -> (data: [TimedSample], timeInterval: SIMD2<Double>)? {
    guard triggerEvents.count > 0 else {
      return nil
    }
    
    func getBestEvent() -> (cursor: Int, centerTime: Double) {
      guard let latestSample else {
        fatalError("This should never happen.")
      }
      let maximumTime = latestSample.time - bipolarHistoryTime
      for i in triggerEvents.indices.reversed() {
        let event = triggerEvents[i]
        if event.centerTime <= maximumTime {
          return event
        }
      }
      
      print("Returning the first event, could not find any matching events.")
      return triggerEvents.first!
    }
    
    let (latestTriggerCursor, centerTime) = getBestEvent()
    let samplePeriod = Double(Self.logPeriodMicros) * 1e-6
    let bipolarSampleCount = Int(bipolarHistoryTime / samplePeriod)
    
    var minimumCursor = latestTriggerCursor - bipolarSampleCount
    minimumCursor = max(minimumCursor, sampleCursor - Self.maxEntryCount)
    minimumCursor = max(minimumCursor, 0)
    
    var maximumCursor = latestTriggerCursor + bipolarSampleCount
    maximumCursor = min(maximumCursor, sampleCursor)
    
    // Some assertions.
    if latestTriggerCursor < sampleCursor - Self.maxEntryCount {
      fatalError("Does this case ever happen?")
    }
    if maximumCursor - minimumCursor < 3 {
      fatalError("Another edge case: \(minimumCursor), \(maximumCursor).")
    }
    
    var output: [TimedSample] = []
    for sampleID in minimumCursor..<maximumCursor {
      let ringIndex = sampleID % Self.maxEntryCount
      let sample = samplesBuffer[ringIndex]
      output.append(sample)
    }
    
    var outputInterval: SIMD2<Double> = .zero
    outputInterval[0] = centerTime - bipolarHistoryTime
    outputInterval[1] = centerTime + bipolarHistoryTime
    return (output, outputInterval)
  }
}
