# 📱 Virtual Tray App Cloner (Flutter + Java)

## 🎯 Objective

To develop an Android application using Flutter (UI) and Java (native backend) that allows users to:

- Install and manage APKs from device storage
- Clone apps by renaming package names
- Support multiple versions of the same app
- Centralize all cloned APKs under user-defined folders
- Analyze APKs for metadata and version control

---

## Currently Implemented Features

### 🔹 Core Functionality
- APK file picker with full file system access
- Manual APK installation using platform channel (Flutter ↔ Java)
- Local folder creation for organizing multiple app clones
- Rename APK clones using custom names and timestamp
- Store clone details using file-based JSON structure

### 🔹 Metadata Extraction
- Extract app name, version, package name, SDK version, and size from APK
- Display metadata in the Flutter UI in an expandable section

### 🔹 UI Features
- Central UI folder for user projects (clone sets)
- Rename functionality for individual clones
- Launch installed apps from within the Flutter app
- Support for physical Android device testing

### 🔹 Permissions
- Requests full storage permission (`MANAGE_EXTERNAL_STORAGE`)
- Handles runtime permission flow properly

---

## Known Issues / Errors

| Issue | Description |
|-------|-------------|
| Installation Failure on Some Devices | APKs may fail to install if `package name` conflicts with existing ones or if APK is unsigned. |
| No Real-Time Clone Launch Isolation | Currently, launching multiple cloned apps does not provide sandbox isolation — only separate installable packages. |
| No Signature Handling | APKs are reinstalled but not re-signed after renaming. This may block installs on stricter Android versions. |

---

## Tech Stack

| Layer | Tech |
|-------|------|
| UI | Flutter |
| Backend | Java (Android) |
| Communication | Flutter `MethodChannel` |
| Permissions | Android `ActivityCompat` and `Settings` Intent |
| APK Tools | Android PackageManager, Java File I/O |


## Improvements

- Requires a search bar for both projects and files for easy access to required files.
- Need to add the linking functionality to the WebPage both via individual projects and direct opening.
- Application can either implement a linked database for both the webpage and application for easy access to modifed apk without additional downloads.
- Need to improve general UI of the application.

---
This app is created for implementing a Multi-Apk Manager that manages the apk into folders/directors for Project based implementation and also implements the app launching and installation functionality for each Apk.The main Purpose of this app is to be integrated with the Cloner Webapp to support Multiple versions of the same apk on a device.As an individual it supports an Apk Manger functionality only for easy integration of Apks.
