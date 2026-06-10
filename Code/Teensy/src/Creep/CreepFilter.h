

// Design: track the voltage change every frame, from the moment the filter is
// turned on.
//
// Very sophisticated, having a delay line with O(log(t)) compute cost.



// We will just test the behavior and execution time of these filters upon
// program start, outside of the feedback loop, for now.