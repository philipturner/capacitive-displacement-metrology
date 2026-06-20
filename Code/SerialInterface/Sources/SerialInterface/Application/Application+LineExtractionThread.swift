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
    usleep(5_000)
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
    
    let splitting = lineParser.split(lines: lines)
    splitting.display()
    
    Application.queue.sync { [self] in
      if let modeCode = splitting.newModeCode {
        let settingsLines = splitting[.imagingSettings]
        ui.reset(modeCode: modeCode, settingsLines: settingsLines)
      }
      
      ui.history.addLines(splitting[.history])
      
      if ui.mode == .imaging {
        ui.imagingWindow.state.trajectory.historyLines += splitting[.history]
        ui.imagingWindow.state.trajectory.imagingLines += splitting[.imaging]
      }
    }
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
        ui.registerDataCorruptionError(error)
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
      let pendingBytes = lineParser.previousPendingBytes
      reset(error: error)
      lineParser.previousPendingBytes = pendingBytes
      
      try! lineParser.count(lines: error.uncorruptedLines)
      lines = error.uncorruptedLines
    } catch {
      fatalError("Unexpected error type.")
    }
    return lines
  }
}
