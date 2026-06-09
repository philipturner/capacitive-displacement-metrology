

// Design: track contiguous series of position changes, mostly the start -> end
// of image, then the subsequent large-scale displacement, even in video mode
//
// Limited in history length, only tracks the largest displacements.