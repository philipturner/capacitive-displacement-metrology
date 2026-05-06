struct PopulationStatistics {
  var sampleSize: Int
  var average: Float
  var standardDeviation: Float
  
  init(data: [Float]) {
    self.sampleSize = data.count
    
    var averageAccumulator: Double = .zero
    for element in data {
      averageAccumulator += Double(element)
    }
    self.average = Float(averageAccumulator) / Float(data.count)
    
    var stddevAccumulator: Double = .zero
    for element in data {
      let delta = element - average
      stddevAccumulator += Double(delta * delta)
    }
    self.standardDeviation = Float(stddevAccumulator)
    
    standardDeviation = standardDeviation / Float(data.count)
    standardDeviation.formSquareRoot()
  }
  
  
  func display() {
    print()
    print("sample size:", sampleSize)
    print("average:", average)
    
    // 1.96-σ magnitude of the uncertainty (±) in the average.
    let confidenceInterval = 1.96 * standardDeviation / Float(sampleSize)
    print("- lower bound:", average - confidenceInterval)
    print("- upper bound:", average + confidenceInterval)
    
    print()
    print("noise:")
    print("- 1σ:", standardDeviation)
    print("- 2σ:", 2 * standardDeviation)
    print("- 3σ:", 3 * standardDeviation)
  }
}
