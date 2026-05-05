import Foundation
import SwiftSerial

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
    print(string, hasStart, hasEnd)
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

for entry in entries {
  print(entry.id, entry.values)
}

await serial.close()
