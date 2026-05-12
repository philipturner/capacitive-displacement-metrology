import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let plt = Python.import("matplotlib.pyplot")
let ticker = Python.import("matplotlib.ticker")

await Application.global.initialize()

while true {
  let frameRate: Int = 30
  usleep(UInt32(1_000_000 / frameRate))
  print("b")
}
