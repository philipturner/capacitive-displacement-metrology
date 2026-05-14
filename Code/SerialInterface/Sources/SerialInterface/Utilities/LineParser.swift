import Foundation
import SwiftSerial

struct LineParser {
  var previousEntryID: Int?
  var totalLineCount: Int = .zero
  var loopIterationID: Int = .zero
  
  mutating func extractEntries(port: SerialPort) -> [Entry] {
    let data = Application.queue.sync {
      try! port.readBytesBlocking(
        count: 1_000_000, timeout: 0.001)
    }
    let validBytes = Self.validBytes(data: data)
    if validBytes.count == 0 {
      return []
    }
    
    // Create the entries while handling a one-time expected error that
    // corrupts the position of start codes.
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
    
    // Check that the entries have contiguous IDs.
    if entries.count > 0 {
      // TODO: Gracefully handle the skipped entries error by resetting the
      // line parser and history. Separate the process of creating the entries
      // from the process of incorporating them into the parser's state tracker.
      //
      // How to simulate the error: if Float.random(in: 0..<1) < 5%, drop one
      // random entry from the list above.
      //
      // Hopefully we can make it possible to replace 'entries' at the above
      // execution point with simulated test entries.
      if let previousEntryID {
        let firstEntryID = entries[0].id
        guard firstEntryID == previousEntryID + 1 else {
          fatalError("""
            Skipped entries: \(previousEntryID) -> \(firstEntryID)
            Error happened between serial port accesses.
            """)
        }
      }
      
      for i in 1..<entries.count {
        let firstEntryID = entries[i - 1].id
        let secondEntryID = entries[i].id
        guard secondEntryID == firstEntryID + 1 else {
          fatalError("""
            Skipped entries: \(firstEntryID) -> \(secondEntryID)
            Error happened contiguously to one serial port access.
            """)
        }
      }
      previousEntryID = entries.last!.id
    }
    totalLineCount += entries.count
    
    // Handle a case where no start codes are detected, and the above code
    // gracefully generates no entries.
    if totalLineCount == 0 {
      // This happens when Teensy is reporting an error message.
      let string = String(decoding: validBytes, as: UTF8.self)
      print("Teensy is responding: \(string)")
    }
    
    return entries
  }
  
  private static func validBytes(data: Data) -> [UInt8] {
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
}
