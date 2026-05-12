import Foundation

struct LineParser {
  var previousEntryID: Int?
  var totalLineCount: Int = .zero
  var loopIterationID: Int = .zero
  
  mutating func extractEntries() async -> [Entry] {
    let serial = Application.global.serial
    let data = try! await serial.readBytesBlocking(
      count: 1_000_000, timeout: 0.001)
    let validBytes = Self.validBytes(data: data)
    if validBytes.count == 0 {
      return []
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
