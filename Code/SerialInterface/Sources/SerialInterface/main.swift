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

/*
enum Mode {
  case riseTime
  case noise
}
func getMode() -> Mode {
  let arguments = CommandLine.arguments
  let input = arguments[1]
  if input == "r" {
    return .riseTime
  } else if input == "n" {
    return .noise
  } else {
    fatalError("Invalid mode.")
  }
}
let mode = getMode()
 */

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

while true {
  usleep(10_000)
  
  do {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = currentTime - startTime
    let formattedString = String(format: "%.3f", elapsedTime)
    print("polling at t = \(formattedString) s")
  }
  
  let readStartTime = Date().timeIntervalSince1970
  let data = try await serial.readBytesBlocking(count: 1_000_000, timeout: 0.001)
  let readEndTime = Date().timeIntervalSince1970
  
  let decodeStartTime = Date().timeIntervalSince1970
  var lineCount: Int = 0
  data.withContiguousStorageIfAvailable { pointer in
    let startCode = Character(">").asciiValue!
    let endCode = Character("<").asciiValue!
    
    var lastStartID: Int?
    var lastEndID: Int?
    var byteID = 0
    while byteID < pointer.count {
      let byte = pointer[byteID]
      if byte == startCode {
        guard lastStartID == nil else {
          fatalError("Unexpected partial entry situation.")
        }
        lastStartID = byteID
        
        byteID = pointer.count
        continue
      }
      
      if byte == endCode {
        if let lastStartID {
          let stringStart = lastStartID + 1
          let stringEnd = byteID
          
          let baseAddress = pointer.baseAddress! + stringStart
          let newBufferPointer = UnsafeBufferPointer(
            start: baseAddress, count: stringEnd - stringStart)
          
          //let entry = Entry(decoding: newBufferPointer)
          //print(entry.id)
          //print(newBufferPointer.count)
          lineCount += 1
        } else {
          guard lastEndID == nil else {
            fatalError("Unexpected partial entry situation.")
          }
          print("Partial entry (end type) of length ~\(byteID).")
        }
        
        lastStartID = nil
        lastEndID = byteID
      }
      
      byteID += 1
    }
    
    if let lastStartID {
      let length = pointer.count - lastStartID
      print("Partial entry (start type) of length ~\(length).")
    }
  }
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
  
  print("processed \(lineCount) lines")
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
