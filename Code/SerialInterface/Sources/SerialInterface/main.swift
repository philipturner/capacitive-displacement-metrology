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

let byte = Character("r").asciiValue!
_ = try await serial.writeBytes([byte])
usleep(60_000)

let data = try await serial.readBytesBlocking(count: 1_000_000, timeout: 0.001)
let string = String(data: data, encoding: .utf8)!
let lines = string.split(separator: "\r\n").map(String.init)

// Decode the serial data.

struct Entry {
  enum ID {
    case start
    case end
    case number(Int)
  }
  var id: ID
  var values: [String]
  
  init?(decoding string: String) {
    let hasStart = (string.first! == ">")
    let hasEnd = (string.last! == "<")
    switch (hasStart, hasEnd) {
    case (true, true):
      break
    case (false, false):
      return nil
    default:
      fatalError("Malformatted string: \(string)")
    }
    
    var shortenedString = string
    shortenedString.removeFirst()
    shortenedString.removeLast()
    
    let substrings = shortenedString
      .split(separator: ",", omittingEmptySubsequences: true)
      .map(String.init)
    guard substrings.count > 0 else {
      fatalError("There were no substrings.")
    }
    
    self.id = Entry.decodeID(substrings[0])
    self.values = Array(substrings[1...])
  }
  
  static func decodeID(_ string: String) -> ID {
    guard string.starts(with: "id:") else {
      fatalError("ID was malformatted.")
    }
    
    var shortenedString = string
    shortenedString.removeFirst(3)
    
    if shortenedString == "start" {
      return ID.start
    } else if shortenedString == "end" {
      return ID.end
    }
    
    if let integerValue = Int(shortenedString) {
      return ID.number(integerValue)
    }
    
    fatalError("No matching ID type.")
  }
}

var entries: [Entry] = []
for line in lines {
  if let entry = Entry(decoding: line) {
    entries.append(entry)
  }
}

guard entries.count > 0 else {
  fatalError("There were no entries.")
}

// Organize into streams.

struct Stream {
  var title: String
  var data: [Float] = []
}

func checkStartAndEnd(_ entries: [Entry]) {
  guard case .start = entries[0].id,
        case .end = entries.last!.id else {
    fatalError("Malformatted entries.")
  }
}

func createStreams(_ entries: [Entry]) -> [Stream] {
  var streams: [Stream] = []
  do {
    let startEntry = entries[0]
    for title in startEntry.values {
      let stream = Stream(title: title)
      streams.append(stream)
    }
  }
  
  var dataEntries = entries
  dataEntries.removeFirst()
  dataEntries.removeLast()
  
  for i in dataEntries.indices {
    let entry = dataEntries[i]
    guard case .number(let entryID) = entry.id else {
      fatalError("Malformatted entry.")
    }
    guard entryID == i else {
      fatalError("Invalid entry ID.")
    }
    guard entry.values.count == streams.count else {
      fatalError("Incorrect number of values.")
    }
    
    for j in entry.values.indices {
      let valueString = entry.values[j]
      guard let value = Float(valueString) else {
        fatalError("Could not decode value.")
      }
      streams[j].data.append(value)
    }
  }
  
  return streams
}

checkStartAndEnd(entries)
let streams = createStreams(entries)

// Graph with Matplotlib.

do {
  // Retrieve the figure and axes.
  let (fig, axis) = plt.subplots().tuple2
  let axes = [axis]
  
  // Set the size of the figure.
   fig.set_size_inches(12, 6)
  
  // Plot on the first subplot.
  axes[0].plot(streams[0].data, streams[1].data, label: streams[1].title)
  axes[0].plot(streams[0].data, streams[2].data, label: streams[2].title)
  axes[0].set_xlabel(streams[0].title)
  
  axes[0].xaxis.set_major_locator(ticker.MultipleLocator(500))
  axes[0].xaxis.set_minor_locator(ticker.MultipleLocator(100))
  
  axes[0].grid(true)
  axes[0].grid(visible: true, which: "minor", axis: "x")
  
  fig.legend(loc: "outside upper left")
  plt.show()
}
