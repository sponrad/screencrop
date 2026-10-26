# Benchmarks

What ScreenCrop costs while it runs, measured on one machine.

## Setup

- MacBook Pro 14-inch, M4 Max (16 CPU cores, 40 GPU cores), macOS 26.6.2.
- Built-in screen only, crop area 1300 × 982 points (2600 × 1964 pixels).
- Charger connected.
- Each phase runs for 60 seconds and reports averages of 2-second samples.

`scripts/bench.sh` takes the samples:

| Column | Source |
|---|---|
| CPU % | `top`, share of one core (100% = one full core) |
| GPU % | `ioreg`, `IOAccelerator` "Device Utilization %" |
| Memory | `top`, resident memory at the end of the phase |
| System W | `ioreg`, `AppleSmartBattery` `PowerTelemetryData.SystemLoad` |

The System W column was not usable on the charger. It jumped between about
11 W and 85 W when the battery started or stopped charging, so the tables
leave it out.

## Desktop use

Hand-driven: idle desktop, then dragging windows and scrolling. Queue depth 5,
cursor fence polled at 120 Hz.

| Phase | ScreenCrop CPU | WindowServer CPU | WindowServer memory |
|---|---|---|---|
| Crop off, idle | — | 2.6% | 1084 MB |
| Crop on, idle | 0.7% | 4.8% | 1240 MB |
| Crop off, motion | — | 27.6% | 1088 MB |
| Crop on, motion | 2.4% | 40.3% | 1240 MB |

When idle, the crop costs about 3% of one core. ScreenCaptureKit sends a frame
only when the screen changes. During motion it costs about 15% of one core.
The motion was by hand, so treat that number as rough.

## Factorio, round 1

Factorio in full screen on the virtual display, same save, no input. Queue
depth 3, cursor fence polled at 120 Hz, virtual display at 60 Hz in every
phase.

| Phase | Capture | GPU % | WindowServer CPU | ScreenCrop CPU | WindowServer memory |
|---|---|---|---|---|---|
| Crop off | — | 22 | 11.0% | — | 608 MB |
| hidpi-60 | 2600 × 1964, 60 fps | 40 | 47.2% | 4.1% | 1258 MB |
| hidpi-30 | 2600 × 1964, 30 fps | 33 | 48.1% | 3.1% | 1258 MB |
| lowres-60 | 1300 × 982, 60 fps | 24 | 52.6% | 4.7% | 968 MB |
| lowres-30 | 1300 × 982, 30 fps | 21 | 49.1% | 3.2% | 948 MB |

## Factorio, round 2

Same save. Queue depth 3, event-based cursor fence. In the 30 Hz phases the
virtual display itself ran at 30 Hz, and Factorio ran at half speed, so those
two rows do not compare with the others.

| Phase | Capture | Display | GPU % | WindowServer CPU | ScreenCrop CPU | WindowServer memory |
|---|---|---|---|---|---|---|
| Crop off | — | — | 22 | 10.9% | — | 833 MB |
| hidpi-60 | 2600 × 1964, 60 fps | 60 Hz | 37 | 48.8% | 4.2% | 1232 MB |
| capture-1fps | 2600 × 1964, 1 fps | 60 Hz | 27 | 30.3% | 0.0% | 1225 MB |
| lowres-60 | 1300 × 982, 60 fps | 60 Hz | 24 | 50.6% | 4.1% | 948 MB |
| hidpi-30 | 2600 × 1964, 30 fps | 30 Hz | 21 | 39.9% | 2.7% | 1255 MB |
| lowres-30 | 1300 × 982, 30 fps | 30 Hz | 17 | 34.5% | 1.8% | 944 MB |

## Conclusions

- During a game, the crop costs WindowServer about 38 points of one core.
  About half comes from the virtual display running at 60 Hz (capture-1fps
  still costs 19 points). The other half comes from the capture.
- The WindowServer cost is per frame, not per pixel. Low resolution and a
  30 fps capture barely change it.
- The default mode costs about 15 points of GPU and 400 MB of WindowServer
  memory. Low resolution brings the GPU back to the uncropped level and saves
  about 285 MB, but text looks soft. It was tried and removed.
- A 30 Hz virtual display halves the cost, but games that tie their
  simulation to the refresh rate, such as Factorio, run at half speed. It was
  tried and removed. The frame rate setting changes only the capture.
- ScreenCrop itself uses about 4% of one core at 60 fps, for its per-frame
  work. The cursor fence was not a measurable part of it.
- A queue depth of 3 saved about 40 MB but made scrolling and cursor movement
  stutter. The queue depth is 5.

## Running a benchmark

```bash
scripts/bench.sh 60 my-label
```

Run it once with the crop on and once with it off, doing the same thing in
both runs. For power numbers, unplug the charger.
