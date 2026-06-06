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
  
  private func lineExtractionLoop(emulator: inout Emulator) {
    usleep(10_000)
    Watchdog.notify(threadID: 1, code: 0)
    
    processSerialInput()
    
    var lines: [LineParser.Line]
    if useEmulator {
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
    Application.queue.sync { [self] in
      // Update the imaging window.
      ui.imagingWindow.pendingSettingsLines += splitting.imagingSettings
      if let newMode = splitting.newMode {
//        if newMode == 8 {
//          ui.imagingModeActive = true
//          ui.imagingWindow.reset()
//        } else {
          ui.imagingModeActive = false
          ui.imagingWindow.state = nil
//        }
        ui.imagingWindow.plotDataValid = false
        ui.historyWindow.plotDataValid = false
      }
      if ui.imagingModeActive {
        if let pauseTime = Application.nextPauseTime {
          let currentTime = Date().timeIntervalSince1970
          if pauseTime < currentTime {
            fatalError(
              "Pausing during imaging would overwhelm the current code.")
          }
        }
        
        ui.imagingWindow.pendingHistoryLines += splitting.history
        ui.imagingWindow.pendingPixelLines += splitting.pixel
      }
      
      // Update the history.
      if splitting.newMode != nil {
        history = History(copying: history)
      }
      history.addLines(splitting.history)
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
    display(lines: splitting.pixel, label: "pixel")
  }
  
  private func processSerialInput() {
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
  }
  
  private func createLines(bytes: [UInt8]) -> [LineParser.Line] {
    func reset(error: LocalizedError) {
      lineParser = LineParser()
      Application.queue.sync {
        if ui.imagingModeActive {
          fatalError(
            "Encountered corrupted data while imaging mode was active.")
        } else {
          history = History(copying: history)
        }
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
