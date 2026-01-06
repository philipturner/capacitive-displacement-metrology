# Capacitive Displacement Metrology

Phase 0.2 of the [APM Roadmap](https://github.com/philipturner/apm-roadmap)

Objective: Finish education in basic mechanical engineering and epoxy handling.

Deadline: March 31, 2026 for the first physical prototype

Table of Contents:
- [December 15, 2025](#december-15-2025)
- [December 16, 2025](#december-16-2025)
- [December 18, 2025](#december-18-2025)
- [December 22, 2025](#december-22-2025)
- [January 3, 2026](#january-3-2026)
- [January 5, 2026](#january-5-2026)
- [January 6, 2026](#january-6-2026)

## December 15, 2025

$80,000 worth of wire transfers have hit the bank. I now have enough financial security to proceed with hardware work.

The first step is ensuring I can be paid a full-time salary. Comply with US tax laws, SEC regulations, etc. I predicted the exact numbers before going through the legal boilerplate and setup.

To save effort, serious work <i>probably</i> won't begin until Jan 2 2026. I can avoid filing a few tax return documents for the 2025 year. I will figure out some remaining tax and paperwork stuff during the last days of 2025.

Current estimate for the press release is Dec 18 2025.

## December 16, 2025

This is ridiculous. The United States is the only country where taxes are such a pain: https://www.propublica.org/article/inside-turbotax-20-year-fight-to-stop-americans-from-filing-their-taxes-for-free

## December 18, 2025

I want to make the creepless SPM happen in the shortest amount of time, and publish transparent data that can be fact-checked. To stay true to my motive, I made another attempt to persuade Robert Wolkow to cooperate. I could save many person-hours, recycling existing designs for creepless SPM hardware.

Regardless of whether he shares any design information, I will proceed according to plan. Any data published by other sources should be treated with extreme skepticism. Do not trust any other lab's data, except data gathered in my own house.

| Phase | Description | Voltage |
| ----: | ----------- | ------: |
| 0.2   | PZT metrology | 24&ndash;40 V |
| 1.1   | LiNbO3 metrology | 850 V |
| 1.2   | LiNbO3 kinematic mount | 850 V |
| 2.1   | LiNbO3 STM, graphite sample | 850 V |
| 2.2   | LiNbO3 STM, inverted mode tip registration | 850 V |

I can shortcut to an important milestone, without the expensive vacuum chamber. Just need to speed up the progress with tripod synthesis. No additional employees or contractors needed for hardware design.

At the end of Phase 0.2, we'll reflect on how long this phase took. If it happened quickly, we can reach the end goal with a single employee. Otherwise, I will probably hire a temporary contractor for hardware design. Phase 2.2 should be completed before Dec 31 2026.

> Nomenclature change: exclude Roman numerals from the phase names, at least when numbering sub-phases. It's highly cumbersome to process "I.1" and "II.2", versus "1.1" and "2.2".
>
> In addition, we may right-align the phase names in tables and spreadsheets.

## December 22, 2025

Still figuring out taxes, but making progress. Putting work on the next MNT animation on hold. Not really motivated when the response to the tutorial is anemic.

Figuring out the details of a possible contract with ChimiaDAO. Our funds should last us well beyond 6 months into the future: oversee completion of Phase 0.2, stable income while raising funds for the next round. Progress on the tripod synthesis will be reported in the Phase 0.2 repository, alongside hardware progress.

## January 3, 2026

We are now sufficiently ready to return to experiments. Paid labor will start on January 5. Rippling costs a ridiculous $1,800 sign-on contract over 18 months ($150 down payment). Definitely not what they publicly advertise or what you get from LLM summaries. In the future, we will face similar obfuscation of quotes from hardware suppliers (e.g. UHV-quality turbopumps cost $14,000 minimum).

## January 5, 2026

I will start by resolving an important unknown. How much does it cost to have 500 nm range instead of 80 nm range for the LiNbO3 piezos? This has implications all through Phase III, where we integrate a custom scanner into the vacuum chamber. It explodes the design cost in Phase III because Wolkow will likely be selling his own design. Already designed hardware is cheaper than the person-hours cost of designing new hardware.

https://www.matsusada.com/corporate/management.html

Might contact Matsusada after doing my own research on their products and my performance requirements.

https://www.matsusada.com/column/hvps-safty.html

### Modeling Power Supply Requirements

To be conservative, assume we'll need 3 kinematic mounts for X, Y, and Z. We're also reducing the range, with 6 plates from Wolkow's patent instead of 10. Now all actuators, for all axes, use 6-high piezo stacks. The capacitance of the kinematic mount probably prevents utilization of the PA94 for high slew rates.

Design options for piezo stack geometry:
- 6 plates, 5 mm x 5 mm area, 6 mm stack height
- 6 plates, 10 mm x 10 mm area, 6 mm stack height
- 10 plates, 10 mm x 10 mm area, 10 mm stack height

The plate area is important now, because smaller plates have less capacitance, and thus lower current pulse requirements for the power supply. We may also use different plate areas for the fine vs. coarse actuators. Mechanically, sticking two 5 mm x 5 mm stacks on top of each other would create a 12 mm high tower. Not a good idea.

### Modeling Piezo Force Requirements

To break static friction, the piezo needs to generate a certain amount of force. In addition to the range and waveform frequency requirements.

Assuming a 0.5 mm thick plate and 69.2 GPa shear modulus:

| Voltage | Displacement | Shear Proportion | Shear Pressure |
| ------: | -----------: | ---------------: | -------------: |
| 200 V   | 13.6 nm      | 2.72e-5          | 1.88e6 Pa      |
| 850 V   | 57.8 nm      | 1.16e-4          | 8.00e6 Pa      |

Forces for various setups at 200 V:

| Plate Size | Plate Count | Shear Force | Max Weight |
| ---------- | ----------: | ----------: | ---------: |
| 5 mm x 5 mm   | 1 | 47.1 N | 4.8 kg |
| 5 mm x 5 mm   | 3 | 141.1 N | 14.4 kg |
| 10 mm x 10 mm | 1 | 188.2 N | 19.2 kg |
| 10 mm x 10 mm | 3 | 564.7 N | 57.6 kg |

Forces for various setups at 800 V:

| Plate Size | Plate Count | Shear Force |
| ---------- | ----------: | ----------: |
| 5 mm x 5 mm   | 1 | 200.0 N | 20.4 kg |
| 5 mm x 5 mm   | 3 | 600.0 N | 61.2 kg |
| 10 mm x 10 mm | 1 | 800.0 N | 81.6 kg |
| 10 mm x 10 mm | 3 | 2399.9 N | 244.9 kg |

Even though shear force doesn't increase with the number of plates per stack, the above numbers should exceed all reasonable force requirements.

### Modeling Required Slew Rate

Dive deeper into the waveform requirements for stick-slip nanopositioning:
- Does the waveform need to contain components above the resonance frequency?
- What is the target rate in steps/second?
- Why is woodpecker coarse tip approach so slow?

These variables can probably be resolved at a later date. I mostly want a lower capacitance in the kinematic mount, while still attaining 30 V/μs slew rate of the PA95 op amp.

### Design Space Exploration

Quiescent current demands on power supply:
- Conservatively 6 DAC channels and 6 PA95 op amps for Phase III
- 6 * 2.2 mA = 13.2 mA

Capacitance (in pF) of entire kinematic mount:
- Piezo plate count is 18 (3 stacks, each with 6 plates)
- Dielectric constant of lithium niobate at 300 K is 88
- Thickness of each plate is 0.5 mm

| Configuration | Capacitance |
| ------------- | ----------: |
| 5 mm x 5 mm   | 701         |
| 10 mm x 10 mm | 2805        |

Current (in mA) required to drive the kinematic mount:

| Configuration | 30 V/μs | 20 V/μs | 10 V/μs | 5 V/μs | 3 V/μs |
| ------------- | ------: | ------: | ------: | -----: | -----: |
| 5 mm x 5 mm   | 21.0    | 14.0    | 7.0     | 3.5    | 2.1    |
| 10 mm x 10 mm | 84.2    | 56.1    | 28.1    | 14.0   | 8.4    |

Power (in W) generated by either of the 450 V power supplies:
- Each supply operates at ~50% duty cycle
- Each supply operates during the respective edge of the waveform
  - +450 V for rising
  - -450 V for falling

| Configuration | 30 V/μs | 20 V/μs | 10 V/μs | 5 V/μs | 3 V/μs |
| ------------- | ------: | ------: | ------: | -----: | -----: |
| 5 mm x 5 mm   | 9.5     | 6.3     | 3.2     | 1.6    | 0.9    |
| 10 mm x 10 mm | 37.9    | 25.2    | 12.6    | 6.3    | 3.8    |

Frequency of an 850 V triangle wave:

| Slew rate (V/μs)     | 30   | 20   | 10  | 5   | 3   |
| -------------------- | ---: | ---: | --: | --: | --: |
| Rise time (μs)       | 28   | 43   | 85  | 170 | 283 |
| Wave period (μs)     | 57   | 85   | 170 | 340 | 567 |
| Wave frequency (kHz) | 17.6 | 11.8 | 5.9 | 2.9 | 1.8 |

### Final Current Demands

Making the smart design choice to use 5 mm instead of 10 mm piezo plates for the kinematic mount.

Providing two negotiable options for maximum waveform frequency: 5.9 kHz, 17.6 kHz

| Wave frequency                        | 5.9 kHz  | 17.6 kHz |
| ------------------------------------- | -------: | -------: |
| Quiescent current                     | 13.2 mA  | 13.2 mA  |
| Current of one active kinematic mount |  7.0 mA  | 21.0 mA  |
| Peak current in either 450 V supply   | 20.2 mA  | 34.2 mA  |
| Peak power in either 450 V supply     | 9.1 W    | 15.4 W   |
| Average power in either 450 V supply  | 7.5 W    | 10.7 W   |
| Total power in both supplies combined | 15.0 W   | 21.3 W   |

I will state the peak (not average) demands when emailing Matsusada.

## January 6, 2026

Still waiting to hear back. Customer service things tend to take a long time, and have many delays.

Where else can I make progress regarding the pathway to a final-state LiNbO3 SPM? The design of a custom UHV chamber with custom electrical feedthroughs. Not the UHV-SPM system that Wolkow might be selling.