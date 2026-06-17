# Notes

Sections of the code that are sometimes disabled for debugging, but should be re-enabled during normal STM operation:
- `KilohertzLoop` checks for timing drift
- `IC::Validation` checks for device ID (leave CRC off for performance reasons)
- `Application` changing USB to 12 Mbit/sec during setup
- Forced mode changes to "tip approach"