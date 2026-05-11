import Foundation

actor CommandTransmitter {
  static let global = CommandTransmitter()
  
  private var characterQueue: String = ""
  
  func addCharacters(_ input: String) {
    characterQueue += input
  }
  
  func extractCharacters() -> String {
    let output = characterQueue
    characterQueue = ""
    return output
  }
  
  static func launchPollingTask() {
    Task.detached {
      while true {
        usleep(50_000)
        
        let userInput = readLine()
        if let userInput {
          await CommandTransmitter.global.addCharacters(userInput)
        }
      }
    }
  }
  
  static func transmitSerialInput() async {
    let input = await CommandTransmitter.global.extractCharacters()
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
    
    let serial = Application.global.serial
    let bytesWritten = try! await serial.writeBytes(asciiValues)
    guard bytesWritten == asciiValues.count else {
      fatalError("Did not write the number of expected bytes.")
    }
    print("Wrote serial input: \(input)")
  }
}
