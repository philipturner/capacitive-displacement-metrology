import IOKit
import IOKit.serial

func findSerialPorts() -> [String] {
    var portPaths: [String] = []
    
    // Create a dictionary to match against serial devices
    let classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue)
    
    var matchingServices: io_iterator_t = 0
    let kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatch, &matchingServices)
    
    if kernResult == KERN_SUCCESS {
        // Iterate through all found services
        while case let service = IOIteratorNext(matchingServices), service != 0 {
            // Get the BSD path (e.g., /dev/cu.usbserial-123)
          if let bsdPath = IORegistryEntryCreateCFProperty(service, ("IOCalloutDevice" as! CFString), kCFAllocatorDefault, 0)
                .takeUnretainedValue() as? String {
                portPaths.append(bsdPath)
            }
            IOObjectRelease(service)
        }
        IOObjectRelease(matchingServices)
    }
    return portPaths
}

// Usage
let ports = findSerialPorts()
print(ports)
