# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FreeAPS X is an artificial pancreas system for iOS based on OpenAPS Reference algorithms (oref0/oref1). It controls insulin pumps (Medtronic, Omnipod) via RileyLink-compatible devices and integrates with various CGM sources.

## Project Setup (Tuist)

This project uses [Tuist](https://tuist.io/) for project generation. The Xcode project and workspace files are generated, not committed.

### First-time Setup

1. Install Tuist (version specified in mise.toml):
   ```bash
   mise install
   ```

2. Create a `.env` file from the example:
   ```bash
   cp .env.example .env
   ```

3. Edit `.env` and set your Apple Developer Team ID:
   ```
   TUIST_DEVELOPER_TEAM=YOUR_TEAM_ID
   ```
   (Team ID can be found in Apple Developer Portal → Membership)

4. Build Dependencies as XCFrameworks:
   ```bash
   ./scripts/build-dependencies.sh
   ```
   This builds LoopKit, RileyLink, CGMBLEKit as XCFrameworks in the `Frameworks/` directory.

5. Generate the Xcode project:
   ```bash
   mise exec -- tuist install          # Install SPM dependencies
   mise exec -- tuist generate --no-open  # Generate Xcode project (without opening Xcode)
   ```
   Or if tuist is in PATH: `tuist install && tuist generate --no-open`

6. Open `FreeAPS.xcworkspace` in Xcode

### Build Commands

```bash
# Generate Xcode project (after changes to Project.swift or dependencies)
mise exec -- tuist generate --no-open

# Build for iOS Simulator
xcodebuild -workspace FreeAPS.xcworkspace -scheme "FreeAPS X" -sdk iphonesimulator build

# Build for iOS Device
xcodebuild -workspace FreeAPS.xcworkspace -scheme "FreeAPS X" -destination "generic/platform=iOS" build

# Run tests
mise exec -- tuist test FreeAPSTests

# Format code
./scripts/swiftformat.sh
```

**Xcode:** Просто открой `FreeAPS.xcworkspace`, выбери симулятор и нажми Run.

## Configuration

Project configuration is managed in Tuist manifests:
- `Project.swift` - Main project definition (targets, dependencies, schemes)
- `Workspace.swift` - Workspace definition
- `Tuist/Package.swift` - SPM dependencies
- `Tuist/ProjectDescriptionHelpers/Project+FreeAPS.swift` - Shared configuration and helpers
- `.env` - Developer-specific settings (not committed)

## Architecture

### Dependency Injection (Swinject)

Services are registered in `FreeAPS/Sources/Assemblies/` and injected via the `@Injected()` property wrapper:
- `StorageAssembly` - File storage and persistence
- `ServiceAssembly` - Core services (Settings, Notifications, HealthKit)
- `APSAssembly` - APS logic (OpenAPS, Device managers)
- `NetworkAssembly` - Nightscout and network services
- `UIAssembly` - Router and UI components
- `SecurityAssembly` - Keychain and security

### Module Structure (MVVM + Provider)

Each UI module in `FreeAPS/Sources/Modules/[Name]/` follows:
- `[Name]StateModel.swift` - ObservableObject with @Published state
- `[Name]Provider.swift` - Data access layer
- `[Name]DataFlow.swift` - Reactive state flow
- `View/[Name]RootView.swift` - SwiftUI view

### OpenAPS JavaScript Integration

The app bundles oref0 JavaScript algorithms in `FreeAPS/Resources/javascript/bundle/` and executes them via JavaScriptCore:
- `OpenAPS.swift` - Main orchestrator for algorithm execution
- `JavaScriptWorker.swift` - JS execution engine with thread-safe context
- Key algorithms: `determine-basal.js`, `iob.js`, `meal.js`, `autosens.js`, `autotune-*.js`

Data flows through JSON files stored in the app's Documents directory (monitor/, settings/, enact/ paths).

### Core Managers

- `APSManager` - Entry point for loop cycle: determineBasal → enactSuggested → loopCompleted
- `DeviceDataManager` - Pump communication via LoopKit's PumpManagerUI protocol
- `FetchGlucoseManager` - 1-minute polling for CGM data from multiple sources

### CGM Sources (`FreeAPS/Sources/APS/CGM/`)

All implement `GlucoseSource` protocol:
- `DexcomSource` - Native Dexcom apps via AppGroup
- `AppGroupSource` - xDrip, GlucoseDirect
- `LibreTransmitterSource` - Direct Bluetooth
- `NightscoutManager` - Online glucose

### Observer Pattern

`Broadcaster` service enables decoupled communication via protocols like `GlucoseObserver`, `SuggestionObserver`, `PumpHistoryObserver`, `SettingsObserver`.

### Property Wrappers

- `@Injected()` - Service dependency injection
- `@Persisted()` - UserDefaults persistence
- `@SyncAccess()` - Thread-safe access with locks

## Dependencies

### Pre-built XCFrameworks (in Frameworks/)

Built from `Dependencies/` using `scripts/build-dependencies.sh`:
- `LoopKit`, `LoopKitUI`, `LoopTestingKit` - Core pump/CGM abstractions and managers
- `MockKit`, `MockKitUI` - Simulator pump for testing
- `RileyLinkBLEKit`, `RileyLinkKit`, `RileyLinkKitUI` - RileyLink Bluetooth communication
- `MinimedKit`, `MinimedKitUI` - Medtronic pump support
- `OmniKit`, `OmniKitUI` - Omnipod pump support
- `CGMBLEKit` - Dexcom G5/G6 BLE integration
- `Crypto` - Cryptographic utilities

### Known Limitations

- **ConnectIQ (Garmin)**: The ConnectIQ framework doesn't support arm64 simulator. It's automatically excluded from simulator builds via conditional compilation. Garmin features are disabled in simulator (shows "Garmin is not available in Simulator" message).

### Source Dependencies (in Dependencies/)

Original Xcode projects (used for building XCFrameworks):
- `LoopKit/` - LoopKit.xcodeproj
- `rileylink_ios/` - RileyLink.xcodeproj
- `CGMBLEKit/` - CGMBLEKit.xcodeproj
- `LibreTransmitter/` - SPM package (used directly via Tuist)

### SPM Dependencies (via Tuist/Package.swift)

- `Swinject` - Dependency injection
- `SwiftDate` - Date handling
- `swift-algorithms` - Collection algorithms
- `SwiftMessages` - In-app notifications
- `LibreTransmitter` - Libre sensor communication

## Code Style

SwiftFormat is configured in `scripts/swiftformat.sh`:
- 4-space indentation
- 130 character max line width
- No file headers
- Remove redundant `self`
- Excludes: Pods, Generated, Dependencies

## Branch Strategy

- `master` - Main/stable branch
- `dev` - Active development, PRs target here
