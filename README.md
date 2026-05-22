<div align="center">

# SwiftCameraZoomDemo

Minimal UIKit + AVFoundation camera zoom demo for iPhone.

![Swift](https://img.shields.io/badge/Swift-5-orange?style=flat-square&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-15%2B-blue?style=flat-square&logo=apple&logoColor=white)
![UIKit](https://img.shields.io/badge/UI-UIKit-black?style=flat-square)
![AVFoundation](https://img.shields.io/badge/Camera-AVFoundation-lightgrey?style=flat-square)

[Overview](#overview) - [Features](#features) - [Getting Started](#getting-started) - [Implementation Notes](#implementation-notes) - [中文说明](#中文说明)

</div>

## Overview

SwiftCameraZoomDemo is a small native iOS sample that demonstrates camera preview and zoom controls using a single `AVCaptureSession`. It is intentionally lightweight: no SwiftUI, no third-party camera framework, no photo library dependency, and no video recording flow.

The UI mirrors the core interaction pattern of the iOS Camera app: a 4:3 preview area, a bottom control dock, fixed zoom stops, pinch-to-zoom, and a shutter button with immediate capture feedback.

> [!NOTE]
> Camera preview requires a physical iPhone. The iOS Simulator can build the app, but it cannot provide a real camera feed.

## Features

- Single `AVCaptureSession` managed on a serial session queue
- Back camera preview displayed in a 4:3 viewport
- Preferred virtual back camera selection:
  - `.builtInTripleCamera`
  - `.builtInDualWideCamera`
  - `.builtInDualCamera`
  - `.builtInWideAngleCamera`
- Fixed zoom controls: `.5`, `1x`, and `2`
- Smooth button zoom using `ramp(toVideoZoomFactor:withRate:)`
- Responsive pinch-to-zoom using direct `videoZoomFactor` updates
- Photo capture with a brief flash overlay, without saving to Photos
- Programmatic UIKit layout, no storyboard UI

## Getting Started

### Requirements

- macOS with Xcode 26 or later
- iOS 15 or later
- A physical iPhone for runtime camera testing
- A valid Apple Development signing identity for device builds

### Clone

```sh
git clone git@github.com:Feiyu-Liu/SwiftCameraZoomDemo.git
cd SwiftCameraZoomDemo
```

### Run in Xcode

1. Open `SwiftCameraZoomDemo.xcodeproj`.
2. Select the `SwiftCameraZoomDemo` scheme.
3. Select a physical iPhone.
4. Run the app.
5. Grant camera permission when prompted.

### Build from the Command Line

Simulator build:

```sh
xcodebuild -project SwiftCameraZoomDemo.xcodeproj \
  -scheme SwiftCameraZoomDemo \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Device build:

```sh
xcodebuild -project SwiftCameraZoomDemo.xcodeproj \
  -scheme SwiftCameraZoomDemo \
  -destination 'generic/platform=iOS' \
  build
```

## Project Structure

```text
SwiftCameraZoomDemo/
├── SwiftCameraZoomDemo.xcodeproj
└── SwiftCameraZoomDemo/
    ├── AppDelegate.swift
    ├── CameraSessionManager.swift
    ├── CameraViewController.swift
    ├── Info.plist
    └── Base.lproj/
        └── LaunchScreen.storyboard
```

## Implementation Notes

`CameraSessionManager` owns the AVFoundation setup:

- Requests camera authorization
- Configures the session with a photo preset
- Selects the preferred back camera
- Adds `AVCaptureDeviceInput` and `AVCapturePhotoOutput`
- Starts and stops capture on a serial queue
- Clamps zoom to the active device's available range

`CameraViewController` owns the UI:

- Lays out the preview layer as full-width 4:3
- Places zoom controls and the shutter in a black bottom dock
- Handles shutter taps and pinch gestures
- Shows lightweight error and capture feedback

For iOS 18 and later, display zoom values are mapped through `displayVideoZoomFactorMultiplier`. On earlier versions, the demo falls back to using the requested zoom value as the raw AVFoundation zoom factor and clamps it safely.

<details>
<summary id="中文说明">中文说明</summary>

## 概览

SwiftCameraZoomDemo 是一个极简的 iOS 原生相机变焦示例，使用 UIKit 和 AVFoundation 实现。项目只保留相机预览和变焦相关能力，不依赖 SwiftUI、不依赖第三方相机库，也不包含录像和相册保存流程。

界面参考 iOS 原生相机的基本交互：4:3 预览窗口、底部黑色控制区、固定变焦档位、双指捏合变焦，以及带拍照反馈的快门按钮。

> [!NOTE]
> 相机预览需要在 iPhone 真机上运行。模拟器可以编译项目，但无法提供真实摄像头画面。

## 功能

- 使用单个 `AVCaptureSession`
- 后置相机默认启动，预览窗口为 4:3
- 后摄优先选择虚拟多摄设备
- 提供 `.5`、`1x`、`2` 三个变焦按钮
- 点击按钮时使用 `ramp(toVideoZoomFactor:withRate:)` 平滑变焦
- 双指捏合时直接更新 `videoZoomFactor`，保持跟手
- 拍照后只显示闪白反馈，不保存到相册
- UIKit 纯代码布局

## 运行

### 环境要求

- Xcode 26 或更新版本
- iOS 15 或更新版本
- 用于测试相机预览的 iPhone 真机
- 可用于真机调试的 Apple Development 签名身份

### 克隆项目

```sh
git clone git@github.com:Feiyu-Liu/SwiftCameraZoomDemo.git
cd SwiftCameraZoomDemo
```

### 使用 Xcode 运行

1. 打开 `SwiftCameraZoomDemo.xcodeproj`。
2. 选择 `SwiftCameraZoomDemo` scheme。
3. 选择一台 iPhone 真机。
4. 点击运行。
5. 首次启动时允许相机权限。

### 命令行编译

模拟器编译：

```sh
xcodebuild -project SwiftCameraZoomDemo.xcodeproj \
  -scheme SwiftCameraZoomDemo \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

真机编译：

```sh
xcodebuild -project SwiftCameraZoomDemo.xcodeproj \
  -scheme SwiftCameraZoomDemo \
  -destination 'generic/platform=iOS' \
  build
```

## 实现说明

`CameraSessionManager` 负责相机能力：权限申请、session 配置、后摄设备选择、拍照输出、启动停止和变焦控制。

`CameraViewController` 负责界面和交互：4:3 预览布局、底部控制区、变焦按钮、快门按钮、捏合手势和拍照反馈。

iOS 18 及更新系统会通过 `displayVideoZoomFactorMultiplier` 做展示倍率到 raw zoom 的换算。旧系统使用请求倍率作为 raw zoom fallback，并始终按设备可用范围做 clamp。

</details>
