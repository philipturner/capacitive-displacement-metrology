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
    print()
    print("polling at t = \(formattedString) s")
    print("loop iteration ID: \(loopIterationID)")
    
//    if loopIterationID == 0 {
//      print("discarding data due to expected corruption")
//      loopIterationID += 1
//      continue
//    } else {
//      loopIterationID += 1
//    }
  }
  
  let decodeStartTime = Date().timeIntervalSince1970
  let entries = decodeEntries(data: validBytes)
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
