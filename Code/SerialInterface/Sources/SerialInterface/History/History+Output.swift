extension History {
  func sampleHistory(time historyTime: Double) -> [TimedSample] {
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
  
  func averageHistory(time historyTime: Double) -> [TimedAverage] {
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
  
  func triggerEventTrace(bipolarHistoryTime: Double) -> (
    data: [TimedSample], timeInterval: SIMD2<Double>
  )? {
    fatalError("Not implemented.")
  }
}
