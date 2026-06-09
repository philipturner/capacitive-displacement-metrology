

// Design: track the voltage change every frame, from the moment the filter is
// turned on.
//
// Very sophisticated, having a delay line with O(log(t)) compute cost.