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

while true {
  usleep(10_000)
  
  let data = try await serial.readBytesBlocking(count: 1_000_000, timeout: 0.001)
  let string = String(data: data, encoding: .utf8)!
  let lines = string.split(separator: "\r\n").map(String.init)
  
  for line in lines {
    let hasStart = (line.first! == ">")
    let hasEnd = (line.last! == "<")
    if hasStart && hasEnd {
      let entry = Entry(decoding: line)
      print("id:", entry.id, "values:", entry.values)
    } else if hasStart || hasEnd {
      print("Not yet handling partial entries:", line)
    } else {
      print(line)
    }
  }
}
