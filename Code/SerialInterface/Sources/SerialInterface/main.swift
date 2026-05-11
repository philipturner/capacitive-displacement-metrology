import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let plt = Python.import("matplotlib.pyplot")
let ticker = Python.import("matplotlib.ticker")

await Application.global.initialize()

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

var previousEntryID: Int?
var totalLineCount: Int = .zero
var loopIterationID: Int = .zero

while true {
  usleep(10_000)
  
  await CommandTransmitter.transmitSerialInput()
  
  let serial = Application.global.serial
  let data = try await serial.readBytesBlocking(
    count: 1_000_000, timeout: 0.001)
  let validBytes = validBytes(data: data)
  if validBytes.count == 0 {
    continue
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
  
  if totalLineCount == 0, validBytes.count > 0 {
    let string = String(decoding: validBytes, as: UTF8.self)
    print("Teensy is responding: \(string)")
  }
}
