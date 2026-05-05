import Foundation
import SwiftSerial

let serial = SerialPort(path: "/dev/cu.usbmodem182280901")

try await serial.open(
  receiveRate: .baud115200,
  transmitRate: .baud115200)
print("opened serial port")

let byte = Character("r").asciiValue!
_ = try await serial.writeBytes([byte])
usleep(100_000)

let data = try await serial.readBytesBlocking(count: 1_000_000, timeout: 1.0)

/*
var receivedData = Data()
while true {
  let fragmentSize = 1000
  let fragment = try await serial.readBytesBlocking(count: 1000, timeout: 1.0)
  print("received fragment of size", fragment.count)
  
  guard let string = String(data: fragment, encoding: .utf8) else {
    fatalError("Could not decode data.")
  }
  print()
  print(string)
  print()
  
  receivedData += fragment
  if fragment.count < fragmentSize {
    break
  }
}

guard let string = String(data: receivedData, encoding: .utf8) else {
  fatalError("Could not decode data.")
}
print()
print(string)
print()
 */

await serial.close()
