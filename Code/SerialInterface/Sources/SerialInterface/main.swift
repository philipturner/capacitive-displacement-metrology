import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let plt = Python.import("matplotlib.pyplot")
let ticker = Python.import("matplotlib.ticker")

// Mode

enum Mode {
  case riseTime
  case noise
}
let mode: Mode = .noise

// Access the serial port.

let serial = SerialPort(path: "/dev/cu.usbmodem182280901")

try await serial.open(
  receiveRate: .baud115200,
  transmitRate: .baud115200)
print("opened serial port")

do {
  var character: Character
  switch mode {
  case .riseTime: character = "r"
  case .noise: character = "n"
  }
  
  _ = try await serial.writeBytes([character.asciiValue!])
  usleep(60_000)
}

_ = try await serial.writeBytes([Character("e").asciiValue!])
usleep(60_000 + 50_000)

let data = try await serial.readBytesBlocking(count: 1_000_000, timeout: 0.015)
let string = String(data: data, encoding: .utf8)!
let lines = string.split(separator: "\r\n").map(String.init)

// Decode the serial data.

var entries: [Entry] = []
for line in lines {
  if let entry = Entry(decoding: line) {
    entries.append(entry)
  }
}

guard entries.count > 0 else {
  fatalError("There were no entries.")
}

// Graph with Matplotlib.

// Retrieve the figure and axes.
let (fig, axis) = plt.subplots().tuple2
let axes = [axis]

// Set the size of the figure.
fig.set_size_inches(12, 6)

// Plot on the first subplot.
let streams = Stream.createStreams(entries)
axes[0].plot(streams[0].data, streams[1].data, label: streams[1].title)
axes[0].plot(streams[0].data, streams[2].data, label: streams[2].title)

// Run the calculation of the property of interest.
if mode == .riseTime {
  let riseTimeStreams = RiseTime.createRiseTimeStreams(streams: streams)
  
  // Display indicators graphically to check correctness of the calculation.
  axes[0].scatter(
    riseTimeStreams.x.data,
    riseTimeStreams.y.data,
    label: riseTimeStreams.y.title)
} else {
  let statistics = PopulationStatistics(data: streams[2].data)
  statistics.display()
}

// Format the subplot.
axes[0].set_xlabel(streams[0].title)
if mode == .riseTime {
  axes[0].xaxis.set_major_locator(ticker.MultipleLocator(500))
  axes[0].xaxis.set_minor_locator(ticker.MultipleLocator(100))
}
axes[0].grid(true)
if mode == .riseTime {
  axes[0].grid(visible: true, which: "minor", axis: "x")
}

fig.legend(loc: "outside upper left")
plt.show()

