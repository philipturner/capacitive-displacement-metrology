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

struct DataLossState {
  nonisolated(unsafe)
  static var firstEntryID: Int?
  nonisolated(unsafe)
  static var lastEntryID: Int?
  nonisolated(unsafe)
  static var totalEntryCount: Int = 0
  
  var decodedEntries: Int
  var expectedEntries: Int
  
  init() {
    if let firstEntryID = Self.firstEntryID,
       let lastEntryID = Self.lastEntryID {
      self.decodedEntries = Self.totalEntryCount
      self.expectedEntries = (lastEntryID - firstEntryID) + 1
    } else {
      self.decodedEntries = 0
      self.expectedEntries = 0
    }
  }
  
  func display() {
    let lostEntries = expectedEntries - decodedEntries
    let lostProportion = Float(lostEntries) / Float(expectedEntries)
    print("lost:", terminator: " ")
    print("\(lostEntries) / \(expectedEntries)", terminator: " ")
    
    let percentString = String(format: "%.2f", lostProportion * 100)
    print("(\(percentString)%)")
  }
}

let startTime = Date().timeIntervalSince1970

while true {
  usleep(10_000)
  
  let readStartTime = Date().timeIntervalSince1970
  let data = try await serial.readBytesBlocking(count: 1_000_000, timeout: 0.001)
  let readEndTime = Date().timeIntervalSince1970
  
  do {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = currentTime - startTime
    let formattedString = String(format: "%.3f", elapsedTime)
    print()
    print("polling at t = \(formattedString) s")
    
    // Easy way to avoid large data loss.
    if (elapsedTime < 0.100) {
      continue
    }
  }
  
  let decodeStartTime = Date().timeIntervalSince1970
  let startState = DataLossState()
  var entries: [Entry] = []
  data.withContiguousStorageIfAvailable { pointer in
    let startCode = Character(">").asciiValue!
    let endCode = Character("<").asciiValue!
    
    func findFirstStartCode() -> Int? {
      var cursor = 0
      var firstStartID: Int?
      while cursor < pointer.count {
        let byte = pointer[cursor]
        if byte == startCode {
          firstStartID = cursor
          break
        }
        cursor += 1
      }
      return firstStartID
    }
    let firstStartID = findFirstStartCode()
    guard let firstStartID else {
      return
    }
    
    // Whether no errors were detected in transmission.
    func passesValidation(cursor: Int) -> Bool {
      guard pointer[cursor] == startCode else {
        print("[cursor = \(cursor)] Unexpected start code: \(pointer[cursor])")
        return false
      }
      
      let nextCursor = cursor + 1 + Entry.messageLength
      guard pointer[nextCursor] == endCode else {
        print("[cursor = \(nextCursor)] Unexpected end code: \(pointer[nextCursor])")
        return false
      }
      
      return true
    }
    
    var cursor = firstStartID
    while cursor + Entry.messageLength + 1 < pointer.count {
      if pointer[cursor + Entry.messageLength + 1] == 0 {
        break
      }
      
      var attemptCount = 0
      while cursor + Entry.messageLength + 1 < pointer.count {
        if pointer[cursor + Entry.messageLength + 1] == 0 {
          break
        }
        
        if !passesValidation(cursor: cursor) {
          cursor += 1
          attemptCount += 1
          continue
        }
        
        if attemptCount > 0 {
          print("Validation succeeded after \(attemptCount) attempts.")
        }
        
        cursor += 1 // <
        
        let stringPointer = UnsafeBufferPointer<UInt8>(
          start: pointer.baseAddress! + cursor,
          count: Entry.messageLength)
        let entry = Entry(decoding: stringPointer)
        
        if let lastEntryID = DataLossState.lastEntryID {
          guard entry.id > lastEntryID else {
            fatalError("Corrupted entry ID.")
          }
          if Int(entry.id) - lastEntryID > 100 {
            print()
            print("massive jump:")
            print(DataLossState.firstEntryID ?? "nil")
            print(DataLossState.lastEntryID ?? "nil")
            print(entry.id)
            print(Int(entry.id) - lastEntryID)
            print()
            print(DataLossState.totalEntryCount)
            print(entries.count)
            print(entry.values)
            print()
            
            // === Failure Rate (threshold: 100 consecutive losses) ===
            //
            // Entry.messageLength = 40
            //
            // logPeriod = 24 μs
            // lost: 171 / 149912 (0.11%)
            // lost: 281 / 242275 (0.12%)
            // lost: 34 / 27986 (0.12%) <-- freeze instead of crash
            // lost: 225 / 196948 (0.11%) <-- resumed after 20s freeze
            // lost: 75 / 58382 (0.13%)
            // lost: 106 / 90037 (0.12%) <-- 51s freeze at t = 2s
            //
            // logPeriod = 48 μs
            // lost: 204 / 123353 (0.17%)
            // lost: 248 / 144311 (0.17%)
            // lost: 479 / 287789 (0.17%)
            // lost: 389 / 235246 (0.17%)
            // lost: 255 / 155445 (0.16%)
            // lost: 485 / 289827 (0.17%)
            // lost: 150 / 93215 (0.16%)
            // lost: 36 / 20822 (0.17%)
            // lost: 1002 / 593964 (0.17%)
            //
            // logPeriod = 96 μs
            // lost: 524 / 265756 (0.20%)
            // lost: 251 / 130861 (0.19%)
            // lost: 104 / 53872 (0.19%)
            // lost: 1778 / 923840 (0.19%) <-- has not failed yet
            // lost: 561 / 294490 (0.19%)
            // lost: 1425 / 740719 (0.19%)
            //
            // logPeriod = 192 μs
            // lost: 677 / 177738 (0.38%) <-- freeze instead of crash
            // lost: 3753 / 981032 (0.38%) <-- has not failed yet
            // lost: 2824 / 739661 (0.38%) <-- has not failed yet
            // lost: 2329 / 610495 (0.38%)
            // lost: 359 / 94454 (0.38%)
            // lost: 3954 / 1035781 (0.38%)
            // lost: 40 / 10555 (0.38%)
            // lost: 653 / 171033 (0.38%) <-- 86s freeze at t = 33s
            //
            // Entry.messageLength = 8
            //
            // logPeriod = 24 μs
            // lost: 1 / 356616 (0.00%)
            // lost: 0 / 670431 (0.00%)
            // lost: 11 / 4178214 (0.00%) <-- has not failed yet
            // lost: 12 / 4011623 (0.00%)
            // lost: 5 / 2235178 (0.00%) <-- long freeze at t = 54s
            // lost: 3 / 1932280 (0.00%)
            fatalError("Too large of a loss.")
          }
        }
        
        if DataLossState.firstEntryID == nil {
          DataLossState.firstEntryID = Int(entry.id)
        }
        DataLossState.lastEntryID = Int(entry.id)
        DataLossState.totalEntryCount += 1
        
        entries.append(entry)
        cursor += Entry.messageLength
        cursor += 1 // <
        cursor += 1 // \r
        cursor += 1 // \n
        
        break
      }
    }
  }
  let endState = DataLossState()
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
  
  
  
  var batchState = endState
  batchState.decodedEntries -= startState.decodedEntries
  batchState.expectedEntries -= startState.expectedEntries
  
  print("[batch stats]")
  batchState.display()
  print("[total stats]")
  endState.display()
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
