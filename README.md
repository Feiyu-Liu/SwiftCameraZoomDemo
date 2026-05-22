# SwiftCameraZoomDemo

A minimal UIKit and AVFoundation camera demo focused on zoom behavior.

## Features

- Single `AVCaptureSession`
- Back camera preview in a 4:3 viewport
- Preferred virtual back camera selection
- `.5`, `1x`, and `2` zoom buttons
- Pinch-to-zoom
- Photo capture feedback without saving to Photos

## Requirements

- Xcode 26 or later
- iOS 15 or later
- A physical iPhone for camera preview

## Run

Open `SwiftCameraZoomDemo.xcodeproj` in Xcode, select the `SwiftCameraZoomDemo` scheme, then run on a physical device.

From the command line:

```sh
xcodebuild -project SwiftCameraZoomDemo.xcodeproj \
  -scheme SwiftCameraZoomDemo \
  -destination 'generic/platform=iOS' \
  build
```
