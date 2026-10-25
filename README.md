# ScreenCrop

Use only the working part of a damaged MacBook screen.

ScreenCrop creates a virtual display that is the size of the working area and
makes it the main display. It streams that display, pixel for pixel, into the
top-left corner of the built-in screen and paints the rest black. The cursor
stays on the virtual display.

ScreenCrop runs only while the built-in screen is the only display. When an
external display connects, ScreenCrop pauses. When the external display
disconnects, ScreenCrop starts again.

## Build and run

```bash
./build.sh
open build/ScreenCrop.app
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
  built-in screen touches it only at a corner, and a timer moves the cursor
  back if it reaches the built-in screen.

## License

MIT. See [LICENSE](LICENSE).
