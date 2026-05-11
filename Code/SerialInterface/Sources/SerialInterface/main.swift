import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let plt = Python.import("matplotlib.pyplot")
let ticker = Python.import("matplotlib.ticker")

// Mode

guard CommandLine.arguments.count == 1 else {
  fatalError("Invalid command line arguments: \(CommandLine.arguments)")
}

// Access the serial port.

let serial = SerialPort(path: "/dev/cu.usbmodem182280901")

try await serial.open(
  receiveRate: .baud115200,
  transmitRate: .baud115200)
print("opened serial port")

// Make a background thread that polls for command-line input, once we are
// displaying data to Matplotlib instead of the console.
/*
do {
  var character: Character
  switch mode {
  case .riseTime: character = "r"
  case .noise: character = "n"
  }
  
  _ = try await serial.writeBytes([character.asciiValue!])
}
 */

let startTime = Date().timeIntervalSince1970
var previousEntryID: Int?
var previousPendingBytes: [UInt8] = []
var totalLineCount: Int

@MainActor
func decodeEntries(data: Data) -> [Entry] {
  let dataArray = previousPendingBytes + [UInt8](data)
  func findFirstIndex() -> Int? {
    for i in dataArray.indices {
      let code = dataArray[i]
      if code == Entry.messageStartCode {
        return i
      }
    }
    return nil
  }
  if previousPendingBytes.count > 0 {
    let firstIndex = findFirstIndex()
    guard let firstIndex, firstIndex == 0 else {
      fatalError("This should never happen.")
    }
  }
  previousPendingBytes = []
  
  var entries: [Entry] = []
  if let firstIndex = findFirstIndex() {
    var cursor = firstIndex
    while true {
      let nextCursor = cursor + Entry.messageLength
      guard nextCursor < dataArray.count else {
        let partialMessage = Array(dataArray[cursor...])
        previousPendingBytes = partialMessage
        break
      }
      
      let currentMessageStart = dataArray[cursor]
      let nextMessageStart = dataArray[nextCursor]
      guard currentMessageStart == Entry.messageStartCode,
            nextMessageStart == Entry.messageStartCode else {
        dataArray.withUnsafeBufferPointer { bufferPointer in
          let buffer = bufferPointer.baseAddress!
          let string1 = Entry.display(buffer + cursor)
          
          var message2Length = dataArray.count - nextCursor
          message2Length = min(message2Length, Entry.messageLength)
          let string2 = Entry.display(
            buffer + nextCursor,
            length: message2Length)
          
          fatalError("""
            Unexpected start codes for two consecutive messages.
            message 1: \(string1)
            message 2: \(string2)
            """)
        }
      }
      
      
    }
  }
}

while true {
  usleep(10_000)
  
  let readStartTime = Date().timeIntervalSince1970
  let data = try await serial.readBytesBlocking(count: 1_000_000, timeout: 0.001)
  let readEndTime = Date().timeIntervalSince1970
  
  do {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = currentTime - startTime
    let formattedString = String(format: "%.3f", elapsedTime)
    print()
    print("polling at t = \(formattedString) s")
    
    // Easy way to avoid large data loss.
//    if (elapsedTime < 0.100) {
//      continue
//    }
  }
  
  let decodeStartTime = Date().timeIntervalSince1970
  
  
  let decodeEndTime = Date().timeIntervalSince1970
  
  do {
    let readElapsedTime = readEndTime - readStartTime
    let formattedString = String(format: "%.3f", readElapsedTime * 1000)
    print("read took \(formattedString) ms")
  }
  do {
    let decodeElapsedTime = decodeEndTime - decodeStartTime
    let formattedString = String(format: "%.3f", decodeElapsedTime * 1000)
    print("decoding took \(formattedString) ms")
  }
  do {
    let timePerLine = Float(decodeEndTime - readStartTime) / Float(entries.count)
    let formattedString = String(format: "%.1f", timePerLine * 1e6)
    print("log period: \(formattedString) μs/line")
  }
  do {
    let timePerLine = Float(decodeEndTime - decodeStartTime) / Float(entries.count)
    let formattedString = String(format: "%.1f", timePerLine * 1e6)
    print("decoding time: \(formattedString) μs/line")
  }
  print("processed \(entries.count) lines")
  print("total so far: \(totalLineCount) lines")
}

/*
 this happens every 50 ms on the PC, with 48 μs log period
 9280 lines/s, expected 20833 lines/s
 
 read took 1.054 ms
 split took 21.111 ms -> 46 μs/line
 decoding took 26.504 ms -> 57 μs/line
 processed 464 lines
 
 this happens every 100 ms on the PC, with 480 μs log period
 2120 lines/s, expected 2083 lines/s
 
 read took 43 ms
 split took 21 ms -> 99 μs/line
 decoding took 19 ms -> 89 μs/line
 processed 212 lines
 
 switching to -Xswiftc -Ounchecked: ~16 ms for each operation, over 100 lines
 */
