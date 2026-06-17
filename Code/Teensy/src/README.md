# Notes

Sections of the code that are often commented out, but should be enabled during runtime:
- `KilohertzLoop` checks for timing drift
- `IC::Validation` checks for device ID (leave CRC off for performance reasons)
- `Application` changing USB to 12 Mbit/sec during setup
- Disabling the forced mode change to "tip approach" to enable offline debugging