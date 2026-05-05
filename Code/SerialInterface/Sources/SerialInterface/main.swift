import Foundation
import PythonKit
import SwiftSerial

// Import Python libraries.
PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let plt = Python.import("matplotlib.pyplot")

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

let sampleEntries = [entries[0], entries[1], entries.last!]
for entry in sampleEntries {
  print(entry.id, entry.values)
}

// Python graphing

// Graph with Matplotlib.
do {
  // Retrieve the figure and axes.
  let (fig, axes) = plt.subplots(2, 1).tuple2
  let ax1 = axes[0]
  let ax2 = axes[1]
  
  // Set the size of the figure.
  fig.set_size_inches(6.4, 8.0)
  
  // Plot on the first subplot.
  ax1.semilogx(plot1.frequencyArray, plot1.amplitudeArray, label: "AD8615")
  ax1.semilogx(plot2.frequencyArray, plot2.amplitudeArray, label: "OP37G")
  ax1.semilogx(plot3.frequencyArray, plot3.amplitudeArray, label: "LTC6090-5")
  ax1.set_xlabel("Frequency (Hz)")
  ax1.set_ylabel("Amplitude (dB)")
  ax1.set_ylim([-50, 150])
  ax1.grid(true)
  
  // Plot on the second subplot.
  ax2.semilogx(plot1.frequencyArray, plot1.phaseArray, label: "AD8615")
  ax2.semilogx(plot2.frequencyArray, plot2.phaseArray, label: "OP37G")
  ax2.semilogx(plot3.frequencyArray, plot3.phaseArray, label: "LTC6090-5")
  ax2.set_xlabel("Frequency (Hz)")
  ax2.set_ylabel("Phase (°)")
  ax2.grid(true)
  
  // 'tight_layout' is needed to prevent axis labels from overlapping other
  // graphs.
  plt.legend()
  plt.tight_layout()
  plt.show()
}


