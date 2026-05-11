import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let plt = Python.import("matplotlib.pyplot")
let ticker = Python.import("matplotlib.ticker")

// Access the serial port.

let serial = SerialPort(path: "/dev/cu.usbmodem182280901")

try await serial.open(
  receiveRate: .baud115200,
  transmitRate: .baud115200)
print("opened serial port")

// Launch the background thread for collecting user input.

actor CommandTransmitter {
  private var characterQueue: String = ""
  
  func addCharacters(_ input: String) {
    characterQueue += input
  }
  
  func extractCharacters() -> String {
    let output = characterQueue
    characterQueue = ""
    return output
  }
}
let transmitter = CommandTransmitter()

Task.detached {
  while true {
    usleep(50_000)
    
    let userInput = readLine()
    if let userInput {
      await transmitter.addCharacters(userInput)
    }
  }
}

func transmitSerialInput() async {
  let input = await transmitter.extractCharacters()
  guard input.count > 0 else {
    return
  }
  
  
}

// Split the data stream into entries.

func validBytes(data: Data) -> [UInt8] {
  var output: [UInt8] = []
  for byte in data {
    // Terminate the data at the first zero code.
    if byte == 0 {
      break
    }
    output.append(byte)
  }
  return output
}

let startTime = Date().timeIntervalSince1970
var previousEntryID: Int?
var totalLineCount: Int = .zero
var loopIterationID: Int = .zero

while true {
  usleep(10_000)
  
  await transmitSerialInput()
  
  let readStartTime = Date().timeIntervalSince1970
  let data = try await serial.readBytesBlocking(count: 1_000_000, timeout: 0.001)
  let validBytes = validBytes(data: data)
  if validBytes.count == 0 {
    continue
  }
  let readEndTime = Date().timeIntervalSince1970
  
  do {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = currentTime - startTime
    let formattedString = String(format: "%.3f", elapsedTime)
    // print()
    // print("polling at t = \(formattedString) s")
    // print("loop iteration ID: \(loopIterationID)")
  }
  defer {
    loopIterationID += 1
  }
  
  func createEntries() -> [Entry] {
    do {
      let entries = try Entry.decodeEntries(data: validBytes)
      return entries
    } catch let error as Entry.StartCodeCorruptionError {
      print(error.description)
      
      if loopIterationID == 0 {
        let data = error.uncorruptedData
        let entries = try! Entry.decodeEntries(data: data)
        return entries
      } else {
        fatalError("This should not happen on later loop iterations.")
      }
    } catch {
      fatalError("Unexpected error type.")
    }
  }
  
  let decodeStartTime = Date().timeIntervalSince1970
  let entries = createEntries()
  if entries.count > 0 {
    if let previousEntryID {
      let firstEntryID = entries[0].id
      guard firstEntryID == previousEntryID + 1 else {
        fatalError("""
          Skipped entries: \(previousEntryID) -> \(firstEntryID)
          """)
      }
    }
    
    for i in 1..<entries.count {
      let firstEntryID = entries[i - 1].id
      let secondEntryID = entries[i].id
      guard secondEntryID == firstEntryID + 1 else {
        fatalError("""
          Skipped entries: \(firstEntryID) -> \(secondEntryID)
          """)
      }
    }
    previousEntryID = entries.last!.id
  }
  totalLineCount += entries.count
  
  let decodeEndTime = Date().timeIntervalSince1970
  
  do {
    let readElapsedTime = readEndTime - readStartTime
    let formattedString = String(format: "%.3f", readElapsedTime * 1000)
    // print("read took \(formattedString) ms")
  }
  do {
    let decodeElapsedTime = decodeEndTime - decodeStartTime
    let formattedString = String(format: "%.3f", decodeElapsedTime * 1000)
    // print("decoding took \(formattedString) ms")
  }
  do {
    let timePerLine = Float(decodeEndTime - decodeStartTime) / Float(entries.count)
    let formattedString = String(format: "%.1f", timePerLine * 1e6)
    // print("decoding time: \(formattedString) μs/line")
  }
  // print("processed \(entries.count) lines")
  // print("total so far: \(totalLineCount) lines")
}
