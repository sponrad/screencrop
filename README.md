<p align="center">
  <img src="Resources/AppIcon.png" alt="ScreenCrop icon" width="160">
</p>

<h1 align="center">ScreenCrop</h1>

<p align="center">Use only the working part of a damaged MacBook screen.</p>

ScreenCrop creates a virtual display that is the size of the working area and
makes it the main display. It streams that display, pixel for pixel, into the
top-left corner of the built-in screen and paints the rest black. The cursor
stays on the virtual display.

ScreenCrop runs only while the built-in screen is the only display. When an
external display connects, ScreenCrop pauses. When the external display
disconnects, ScreenCrop starts again.

## Install

1. Download `ScreenCrop-vX.Y.Z.zip` from the
   [latest release](https://github.com/sponrad/screencrop/releases/latest).
2. Unzip it, and move `ScreenCrop.app` to `/Applications`.
3. Open the app. The release has no Apple Developer ID signature, so macOS
   blocks it the first time. Go to System Settings > Privacy & Security, and
   click **Open Anyway** next to the ScreenCrop message. You can also clear
   the download flag from a terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/ScreenCrop.app
   ```

## Build and run

```bash
./build.sh
open build/ScreenCrop.app
```

The build is a universal app for Apple silicon and Intel Macs.

## Release

Push a version tag. The `Release` workflow builds the app and attaches a zip
to a new GitHub release.

```bash
git tag v0.1.0
git push origin v0.1.0
```

On the first run, grant Screen Recording permission in System Settings >
Privacy & Security > Screen & System Audio Recording. Then open the app again.
The build has an ad-hoc signature, so macOS can ask again after a rebuild.

For a safe trial, quit after a set number of seconds:

```bash
open build/ScreenCrop.app --args --for 60
```

## Use

- Press ⌃⌥⌘C to turn the crop on or off.
- The ◧ menu bar item shows the state and has Quit.
- The ◧ menu sets the capture frame rate, 60 or 30 fps. 30 fps saves a little
  GPU work. The virtual display stays at 60 Hz, so games keep full speed.
- If ScreenCrop quits or crashes, macOS removes the virtual display and the
  normal screen comes back.

Windows that were open on the built-in screen stay there, under the black
overlay. To move a window to the virtual display, use a window manager such as
Rectangle (⌃⌥⌘← for "Previous Display").

## Settings

The working area is given in points and starts at the top-left corner. The
default is 1300 × 982, which is the left part of a 14-inch MacBook Pro screen
at its default resolution. Keep the built-in screen at that default
resolution.

```bash
defaults write com.sponrad.ScreenCrop width -int 1300
defaults write com.sponrad.ScreenCrop height -int 982
```

## How it works

- `CGVirtualDisplay`, a private CoreGraphics API, creates the virtual display
  with a HiDPI mode.
- ScreenCaptureKit captures that display. Each frame goes onto a layer in a
  borderless window on the built-in screen.
- The virtual display sits at the origin, so it is the main display. The
  built-in screen touches it only at a corner, and a mouse event monitor moves
  the cursor back if it reaches the built-in screen.

While the crop runs, WindowServer uses about 3% more of one CPU core on an
idle desktop and about 38% more during a full-screen game. See
[benchmarks](docs/benchmarks.md) for the measurements, and
[alternatives](docs/alternatives.md) for the other approaches that were tried.

## License

MIT. See [LICENSE](LICENSE).
