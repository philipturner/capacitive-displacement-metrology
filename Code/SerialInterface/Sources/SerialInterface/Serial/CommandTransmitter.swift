import Foundation
import SwiftSerial

class CommandTransmitter {
  nonisolated(unsafe)
  private static var characterQueue: String = ""
  
  static func addCharacters(_ input: String) {
    characterQueue += input
  }
  
  static func extractCharacters() -> String {
    let output = characterQueue
    characterQueue = ""
    return output
  }
  
  static func startPollingThread() {
    DispatchQueue.global().async {
      while !Application.needsToClose {
        usleep(50_000)
        
        let userInput = readLine()
        if let userInput {
          Application.queue.sync {
            Self.addCharacters(userInput)
          }
        }
      }
    }
  }
  
  static func transmitSerialInput(_ input: String, port: SerialPort) {
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
}
