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

let streams = Stream.createStreams(entries)
let riseTimeStreams = RiseTime.createRiseTimeStreams(streams: streams)

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
  axes[0].scatter(
    riseTimeStreams.x.data,
    riseTimeStreams.y.data,
    label: riseTimeStreams.y.title)
  
  // Format the subplot.
  axes[0].set_xlabel(streams[0].title)
  axes[0].xaxis.set_major_locator(ticker.MultipleLocator(500))
  axes[0].xaxis.set_minor_locator(ticker.MultipleLocator(100))
  axes[0].grid(true)
  axes[0].grid(visible: true, which: "minor", axis: "x")
  
  fig.legend(loc: "outside upper left")
  plt.show()
}
