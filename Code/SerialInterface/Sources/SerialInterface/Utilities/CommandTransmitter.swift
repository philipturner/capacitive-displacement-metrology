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
  
  func transmitSerialInput(port: SerialPort) {
    let input = Application.queue.sync {
      self.extractCharacters()
    }
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
    print("Wrote serial input: \(input)")
  }
}
