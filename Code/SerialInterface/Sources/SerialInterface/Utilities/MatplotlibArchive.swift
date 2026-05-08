#if false
func matplotlibArchive() {
  // Retrieve the figure and axes.
  let (fig, axis) = plt.subplots().tuple2
  let axes = [axis]

  // Set the size of the figure.
  fig.set_size_inches(12, 6)

  // Plot on the first subplot.
  let streams = Stream.createStreams(entries)
  if mode == .riseTime {
    let sectionAverages = RiseTime.createSectionAverages(streams: streams)
    let scaleFactor = sectionAverages[0] / 10
    
    var data = streams[1].data
    for i in data.indices {
      data[i] *= scaleFactor * 1.5
    }
    axes[0].plot(streams[0].data, data, label: streams[1].title)
  }
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
    let majorTick = RiseTime.halfPeriodMicroseconds
    axes[0].xaxis.set_major_locator(ticker.MultipleLocator(majorTick))
    axes[0].xaxis.set_minor_locator(ticker.MultipleLocator(majorTick / 5))
  }
  axes[0].grid(true)
  if mode == .riseTime {
    axes[0].grid(visible: true, which: "minor", axis: "x")
  }

  fig.legend(loc: "outside upper left")
  plt.show()
}
#endif
