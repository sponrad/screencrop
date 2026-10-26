# Alternatives

Other ways to use only the working part of a damaged screen, and why
ScreenCrop does not use them. Tested on a 14-inch MacBook Pro (M4 Max) with
macOS 26, with a dead strip along the right edge.

## Summary

| Approach | Result |
|---|---|
| macOS resolution settings | Scale the whole picture. Do not avoid an edge. |
| Window manager gaps (Rectangle) | Free and costless, but full-screen apps and the menu bar still use the dead strip. |
| SimpleDisplay | Cannot mirror a virtual display on macOS 26. |
| DeskPad | Virtual display in a window. The cursor and shortcuts leave the window. |
| BetterDisplay | Works with the same design as ScreenCrop. The feature needs a Pro license. |
| Metal | Does not reach the costs that matter. |
| Display override file | Works, but macOS always centers the picture. |
| Display driver or firmware | Not reachable on Apple Silicon. |

## macOS resolution settings

Every built-in mode either fills the whole panel or, on notched MacBooks,
leaves the band beside the notch black. No setting moves the desktop away
from a side edge.

## Window manager gaps

Rectangle can keep a gap at a screen edge:

```bash
defaults write com.knollsoft.Rectangle screenEdgeGapRight -int 212
```

Snapped and maximized windows then stay out of the dead strip. This costs
nothing, but full-screen apps, the right side of the menu bar, and new
windows still use the strip. The gap also applies to every screen unless
`screenEdgeGapsOnMainScreenOnly` is set.

## SimpleDisplay

[SimpleDisplay](https://simpledisplay.app/) is free and creates virtual
displays. The usual trick is to mirror a smaller virtual display onto the
built-in screen. Its documentation says a virtual display cannot be a mirror
source on macOS 26 because that crashes WindowServer, and the app refuses to
do it.

## DeskPad

[DeskPad](https://github.com/Stengo/DeskPad) shows a virtual display inside a
normal window. You can size the window to the working area, but the cursor,
keyboard shortcuts and full-screen apps can leave it. ScreenCrop uses the
same private `CGVirtualDisplay` API.

## BetterDisplay

[BetterDisplay](https://betterdisplay.pro/) has a guide for this case, "Use
the working part of a damaged screen." It creates a virtual display and
streams it into a chosen part of the damaged screen. This is the same design
as ScreenCrop, and the trial showed that it works. The streaming feature
needs a Pro license.

## Metal

Metal draws an app's own pixels. It cannot change where WindowServer places
the desktop, and it cannot read another display's picture. In ScreenCrop it
could only replace the last step, which shows each frame on the overlay. That
step already hands over the frame's IOSurface with no copy. The measured
costs are the virtual display at 60 Hz and the ScreenCaptureKit capture (see
[benchmarks](benchmarks.md)), and Metal reaches neither.

## Display override file

macOS reads display override files from
`/Library/Displays/Contents/Resources/Overrides`, and they work for the
built-in panel on Apple Silicon. Apple ships one for this panel at
`/System/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-610/DisplayProductID-a061`.
Its `scale-resolutions` list adds the scaled modes.

The test copied Apple's file to `/Library/...` and added two modes, given as
width and height in pixels:

```
00000880 000007ac   2176 × 1964 (1088 × 982 HiDPI)
00000a28 000007ac   2600 × 1964 (1300 × 982 HiDPI)
```

After a restart both modes appeared, at 120 Hz. macOS placed both in the
center of the panel:

| Mode | Bars | Result |
|---|---|---|
| 1300 × 982 | about 106 points on each side | Half of the dead strip stays inside the picture. |
| 1088 × 982 | about 212 points on each side | The dead strip is covered, but 212 points are lost on the left. |

The display hardware does the placement, so this costs nothing at run time.
But no setting in the file moves the picture to one side. For damage on one
edge, a centered mode gives up twice the damaged width. ScreenCrop keeps
1300 points instead of 1088.

To undo the test, delete the file and restart:

```bash
sudo rm /Library/Displays/Contents/Resources/Overrides/DisplayVendorID-610/DisplayProductID-a061
```

## Display driver or firmware

The notch modes show that the display coprocessor (DCP) can place a smaller
desktop at an offset. The DCP firmware supplies the mode list, and it offers
only full-panel and below-notch placements. The frame buffer driver
(`IOMobileFramebuffer`) has one client, WindowServer, and its registry shows
no offset or underscan property for this panel. Changing the placement would
mean patching the driver or the signed DCP firmware, which is not possible
on Apple Silicon without turning off system protections, if at all.
