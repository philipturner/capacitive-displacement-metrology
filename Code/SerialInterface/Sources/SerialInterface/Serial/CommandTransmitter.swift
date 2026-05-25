import Foundation
import SwiftSerial

class CommandTransmitter: @unchecked Sendable {
  private var characterQueue: String = ""
  
  init() {
    
  }
  
  func addCharacters(_ input: String) {
    characterQueue += input
  }
  
  func extractCharacters() -> String {
    let output = characterQueue
    characterQueue = ""
    return output
  }
  
  func startPollingThread() {
    DispatchQueue.global().async {
      while true {
        usleep(50_000)
        
        let userInput = readLine()
        if let userInput {
          Application.queue.sync {
            self.addCharacters(userInput)
          }
        }
      }
    }
  }
  
  func transmitSerialInput(_ input: String, port: SerialPort) {
    guard input.count > 0 else {
      return
    }
    
    var asciiValues: [UInt8] = []
    for character in input {
      guard let asciiValue = character.asciiValue else {
        fatalError("Input character was not ASCII: \(character)")
      }
      asciiValues.append(asciiValue)
    }
    guard asciiValues.last! != 0 else {
      fatalError("Unexpected null termination.")
    }
    
    let bytesWritten = Application.queue.sync {
      try! port.writeBytes(asciiValues)
    }
    guard bytesWritten == asciiValues.count else {
      fatalError("Did not write the number of expected bytes.")
    }
    print("Transmitted serial input: \(input)")
  }
  
  func updateLabels(_ input: String, ui: UI) {
    guard input.count > 0 else {
      return
    }
    
    /*
    var labels: [String]
    switch input.first! {
    case "0":
      labels = [
        "current (A)",
        "sample bias (V)",
        "capacitance (F)",
        "phase shift (°)"
      ]
    case "1":
      labels = [
        "current (A)",
        "tested channel (V)",
        "channel ID",
        "n/a"
      ]
    case "2":
      labels = [
        "current (A)",
        "sample bias (V)",
        "capacitance (F)",
        "phase shift (°)"
      ]
    case "3":
      labels = [
        "current (A)",
        "piezo Z (V)",
        "capacitance (F)",
        "phase shift (°)"
      ]
    case "4":
      labels = [
        "current (A)",
        "piezo Z (nm)",
        "tip crashed (>5 nA)",
        "position error (m)",
      ]
    default:
      return
    }
    
    for i in 0..<5 {
      let labelText = labels[i]
      ui.labels[i].setText(labelText)
    }
     */
  }
}
