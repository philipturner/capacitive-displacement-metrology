import Foundation

struct Watchdog {
  static let queue = DispatchQueue(label: "watchdog")
  static let hangTimeThreshold: Double = 2
  static let okReportInterval: Double = 10
  
  nonisolated(unsafe)
  static var startTime: Double = -1
  nonisolated(unsafe)
  static var nextReportTime: Double = -1
  nonisolated(unsafe)
  static var threadLatestTimes: [Double] = []
  
  static func initialize(trackedThreads: Int) {
    guard threadLatestTimes.count == 0 else {
      fatalError("Cannot initialize twice.")
    }
    guard trackedThreads > 0 else {
      fatalError("Tracked threads cannot be zero.")
    }
    
    startTime = Date().timeIntervalSince1970
    nextReportTime = startTime + okReportFrequency
    
    threadLatestTimes = Array(
      repeating: startTime, count: trackedThreads)
    startReportingThread()
  }
  
  static func notify(threadID: Int) {
    Watchdog.queue.sync {
      guard threadID >= 0,
            threadID < threadLatestTimes.count else {
        fatalError("Invalid thread ID.")
      }
      
      let time = Date().timeIntervalSince1970
      threadLatestTimes[threadID] = time
    }
  }
  
  static func startReportingThread() {
    DispatchQueue.global().async {
      while true {
        usleep(500_000)
        
        Watchdog.queue.sync {
          let currentDate = Date()
          let currentTime = currentDate.timeIntervalSince1970
          
          var shouldReportOK = false
          if currentTime > nextReportTime {
            shouldReportOK = true
            nextReportTime += okReportInterval
            
            if currentTime > nextReportTime {
              fatalError("""
                Unexpected behavior from watchdog.
                \(currentTime)
                \(nextReportTime)
                """)
            }
          }
          
          var threadHangTimes: [Double] = []
          for threadTime in threadLatestTimes {
            let hangTime = currentTime - threadTime
            threadHangTimes.append(hangTime)
          }
          let failed = threadHangTimes.contains(where: {
            $0 > hangTimeThreshold
          })
          
          if failed {
            print("[\(currentDate)] Watchdog report: BAD")
            for threadID in threadHangTimes.indices {
              print("- threads[\(threadID)]:", terminator: " ")
              
              let hangTime = threadHangTimes[threadID]
              let formattedTime = String(format: "%.3f", hangTime)
              print("\(formattedTime) s")
            }
          } else if shouldReportOK {
            print("[\(currentDate)] Watchdog report: OK")
          }
        }
      }
    }
  }
}
