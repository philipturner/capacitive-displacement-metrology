import Foundation

extension Application {
  func startLineExtractionThread() {
    DispatchQueue.global().async { [self] in
      var emulator = Emulator()
      while !Application.needsToClose {
        lineExtractionLoop(emulator: &emulator)
      }
    }
  }
  
  func lineExtractionLoop(emulator: inout Emulator) {
    usleep(10_000)
    Watchdog.notify(threadID: 1, code: 0)
    
    let input = Application.queue.sync {
      CommandTransmitter.extractCharacters()
    }
    if input == "p" {
      let currentTime = Date().timeIntervalSince1970
      if Application.nextPauseTime == nil {
        Application.nextPauseTime = currentTime
      } else {
        Application.nextPauseTime = nil
      }
    } else if input.count > 0 {
      CommandTransmitter.transmitSerialInput(input, port: port)
    }
    
    var lines: [LineParser.Line]
    if Self.serialEmulation {
      lines = emulator.update()
    } else {
      do {
        let bytes = try LineParser.getValidBytes(port: port)
        lines = createLines(bytes: bytes)
      } catch {
        Application.needsToClose = true
        return
      }
    }
    
    let splitting = Flags.split(lines: lines)
    Application.queue.sync {
      if splitting.newMode != nil {
        self.history = History(copying: self.history)
      }
      self.history.addLines(splitting.history)
    }
    
    func display(lines: [LineParser.Line], label: String?) {
      for line in lines {
        if let label {
          print(label, terminator: ": ")
        }
        for laneID in 0..<5 {
          let value = line.values[laneID]
          print(value, terminator: ", ")
        }
        print()
      }
    }
    display(lines: splitting.spectroscopy, label: nil)
    display(lines: splitting.imagingSettings, label: "imaging settings")
    if splitting.newMode == 8 {
      print("switched to imaging mode")
    }
    display(lines: splitting.imaging, label: "imaging")
  }
  
  private func createLines(bytes: [UInt8]) -> [LineParser.Line] {
    func reset(error: LocalizedError) {
      lineParser = LineParser()
      Application.queue.sync {
        // This may cause undefined behavior when the UI for imaging is
        // implemented.
        self.history = History(copying: self.history)
      }
    }
    
    var lines: [LineParser.Line]
    do {
      lines = try lineParser.decode(bytes: bytes)
    } catch let error as LineParser.StartCodeCorruptionError {
      reset(error: error)
      lines = try! lineParser.decode(bytes: error.uncorruptedBytes)
    } catch {
      fatalError("Unexpected error type.")
    }
    
    do {
      try lineParser.count(lines: lines)
    } catch let error as LineParser.NonContiguousError {
      reset(error: error)
      try! lineParser.count(lines: error.uncorruptedLines)
      lines = error.uncorruptedLines
    } catch {
      fatalError("Unexpected error type.")
    }
    return lines
  }
}
