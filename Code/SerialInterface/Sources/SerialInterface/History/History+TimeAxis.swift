extension History {
  struct TimeAxis {
    var shortLength: Double
    var shortMajorTick: Double
    var longLength: Double
    var longMajorTick: Double
    
    init(descriptor: HistoryDescriptor) {
      guard let shortTimeLength = descriptor.shortTimeLength,
            let longTimeLength = descriptor.longTimeLength else {
        fatalError("Descriptor was incomplete.")
      }
      
      self.shortLength = shortTimeLength
      self.shortMajorTick =
      descriptor.shortTimeMajorTick ?? shortTimeLength / 5
      
      self.longLength = longTimeLength
      self.longMajorTick =
      descriptor.longTimeMajorTick ?? longTimeLength / 5
    }
  }
}
