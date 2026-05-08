#if false
enum RiseTime {
  static let halfPeriodMicroseconds: Float = 500
  
  // Find the average in each section.
  static func createSectionAverages(streams: [Stream]) -> [Float] {
    var sectionAverages: [Float] = []
    for sectionID in 0..<6 {
      let startTime = (Float(sectionID) + 0.3) * halfPeriodMicroseconds
      let endTime = (Float(sectionID) + 0.9) * halfPeriodMicroseconds
      
      var accumulator: Float = .zero
      var sampleSize: Int = .zero
      for entryID in streams[0].data.indices {
        let time = streams[0].data[entryID]
        guard time >= startTime,
              time <= endTime else {
          continue
        }
        
        let current = streams[2].data[entryID]
        accumulator += current
        sampleSize += 1
      }
      
      let average = accumulator / Float(sampleSize)
      sectionAverages.append(average)
    }
    
    return sectionAverages
  }
  
  // Find the 90% rise time.
  static func createRiseTimeStreams(
    streams: [Stream],
  ) -> (x: Stream, y: Stream) {
    let sectionAverages = createSectionAverages(streams: streams)
    var streamX = Stream(title: "rise time estimation")
    var streamY = Stream(title: "rise time estimation")
    
    var riseTimes: [Float] = []
    for sectionID in 0..<5 {
      let startCurrent = sectionAverages[sectionID]
      let endCurrent = sectionAverages[sectionID + 1]
      
      var firstSample: SIMD2<Float>?
      var secondSample: SIMD2<Float>?
      var below90Sample: SIMD2<Float>?
      var above90Sample: SIMD2<Float>?
      
      let searchStartTime = (Float(sectionID) + 1) * halfPeriodMicroseconds
      for entryID in streams[0].data.indices {
        let time = streams[0].data[entryID]
        guard time >= searchStartTime else {
          continue
        }
        
        let current = streams[2].data[entryID]
        let progress = (current - startCurrent) / (endCurrent - startCurrent)
        let sample = SIMD2<Float>(time, progress)
        
        if progress > 0.10 {
          if firstSample == nil {
            firstSample = sample
          } else if secondSample == nil {
            secondSample = sample
          }
        }
        
        if progress > 0.90 {
          above90Sample = sample
          break
        } else {
          below90Sample = sample
        }
      }
      
      guard let firstSample,
            let secondSample,
            let below90Sample,
            let above90Sample else {
        fatalError("Could not extract all samples.")
      }
      
      print()
      print(firstSample)
      print(secondSample)
      print(below90Sample)
      print(above90Sample)
      
      guard below90Sample[0] >= secondSample[0] else {
        print("Sample is no good, discarding.")
        continue
      }
      
      func interpolateTime(
        start: SIMD2<Float>,
        end: SIMD2<Float>,
        targetCurrentProgress: Float
      ) -> Float {
        let timeProgress = (targetCurrentProgress - start[1]) / (end[1] - start[1])
        return timeProgress * end[0] + (1 - timeProgress) * start[0]
      }
      
      let time0 = interpolateTime(
        start: firstSample,
        end: secondSample,
        targetCurrentProgress: 0.00)
      let time90 = interpolateTime(
        start: below90Sample,
        end: above90Sample,
        targetCurrentProgress: 0.90)
      streamX.data.append(time0)
      streamX.data.append(time90)
      
      let current0 = 0.00 * endCurrent + (1 - 0.00) * startCurrent
      let current90 = 0.90 * endCurrent + (1 - 0.90) * startCurrent
      streamY.data.append(current0)
      streamY.data.append(current90)
      
      let riseTime = time90 - time0
      riseTimes.append(riseTime)
      
      print("time @  0% |", String(format: "%.1f", time0))
      print("time @ 90% |", String(format: "%.1f", time90))
      print("rise time  |", String(format: "%.1f", riseTime))
    }
    
    let averageRiseTime = riseTimes.reduce(0, +) / Float(riseTimes.count)
    print()
    print("average rise time:", String(format: "%.1f", averageRiseTime))
    
    return (x: streamX, y: streamY)
  }
}
#endif
