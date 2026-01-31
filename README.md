# FreeAPS X

FreeAPS X - an artificial pancreas system for iOS based on [OpenAPS Reference](https://github.com/openaps/oref0) algorithms

FreeAPS X uses original JavaScript files of oref0 and provides a user interface (UI) to control and set up the system

## Documentation

[Overview & Onboarding Tips on Loop&Learn](https://www.loopandlearn.org/freeaps-x/)

[OpenAPS documentation](https://openaps.readthedocs.io/en/latest/)

## Smartphone requirements

- All iPhones which support iOS 18 and up.

## Supported pumps

To control an insulin pump FreeAPS X uses modified [rileylink_ios](https://github.com/ps2/rileylink_ios) library, thus supporting the same pump list:

- Medtronic 515 or 715 (any firmware)
- Medtronic 522 or 722 (any firmware)
- Medtronic 523 or 723 (firmware 2.4 or lower)
- Medtronic Worldwide Veo 554 or 754 (firmware 2.6A or lower)
- Medtronic Canadian/Australian Veo 554 or 754 (firmware 2.7A or lower)
- Omnipod "Eros" pods

To control an insulin you need to have a [RileyLink](https://getrileylink.org), OrangeLink, Pickle, GNARL, Emalink, DiaLink or similar device

## Build Instructions

This project uses [Tuist](https://tuist.io/) for project generation and [mise](https://mise.jdx.dev/) for tool version management.

### Prerequisites

1. **Install mise** (tool version manager):
   ```bash
   curl https://mise.run | sh
   ```

   Add to your shell profile (`~/.zshrc` or `~/.bashrc`):
   ```bash
   eval "$(mise activate zsh)"  # or bash
   ```

   Restart your terminal or run `source ~/.zshrc`

2. **Install Xcode** from the App Store (version 16.0 or later)

### First-time Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ivalkou/freeaps.git
   cd freeaps
   ```

2. **Install tools** (Tuist version is specified in mise.toml):
   ```bash
   mise install
   ```

3. **Create configuration file:**
   ```bash
   cp .env.example .env
   ```

4. **Edit `.env`** and set your Apple Developer Team ID:
   ```
   TUIST_DEVELOPER_TEAM=YOUR_TEAM_ID
   ```
   You can find your Team ID in [Apple Developer Portal](https://developer.apple.com/account) -> Membership -> Team ID

5. **Build dependencies** (XCFrameworks for LoopKit, RileyLink, etc.):
   ```bash
   ./scripts/build-dependencies.sh
   ```

6. **Generate the Xcode project:**
   ```bash
   mise exec -- tuist install
   mise exec -- tuist generate
   ```

   Or if you added mise activation to your shell profile:
   ```bash
   tuist install
   tuist generate
   ```

7. **Open the project** in Xcode:
   ```bash
   open FreeAPS.xcworkspace
   ```

### Regenerating the Project

After modifying `Project.swift`, `Tuist/Package.swift`, or other Tuist configuration files:

```bash
tuist generate
```

If you added new SPM dependencies:

```bash
tuist install && tuist generate
```

## Current state of FreeAPS X

FreeAPS X is in an active development state and changes frequently.

You can find a description of versions on the [releases page](https://github.com/ivalkou/freeaps/releases).

### Stable versions

A stable version means that it has been tested for a long time and does not contain critical bugs. We consider it ready for everyday use.

Stable version numbers end in **.0**.

### Beta versions

Beta versions are the first to introduce new functionality. They are designed to test and identify issues and bugs.

**Beta versions are fairly stable, but may contain occasional bugs.**

Beta numbers end with a number greater than **0**.

## Contribution

Pull requests are accepted on the [dev branch](https://github.com/ivalkou/freeaps/tree/dev).

Bug reports and feature requests are accepted on the [Issues page](https://github.com/ivalkou/freeaps/issues).

## Implemented

- All base functions of oref0
- All base functions of oref1 (SMB, UAM and others)
- Autotune
- Autosens
- Nightscout BG data source as a CGM (Online)
- Applications that mimic Nightscout as a CGM (apps like Spike and Diabox) (Offline)
- [xDrip4iOS](https://github.com/JohanDegraeve/xdripswift) data source as a CGM via shared app gpoup (Offline)
- [GlucoseDirectApp](https://github.com/creepymonster/GlucoseDirectApp) data source as a CGM via shared app gpoup (Offline)
- Libre 1 transmitters and Libre 2 direct as a CGM
- Simple glucose simulator
- System state upload to Nightscout
- Remote carbs enter and temporary targets through Nightscout
- Remote bolusing and insulin pump control
- Dexcom offline support (beta)
- Detailed oref preferences description inside the app (beta)
- User notifications of the system and connected devices state (beta)
- Apple Watch app (beta)
- Enlite support (beta)
- Apple Health support for blood glucose (beta)
- Daily automatic backup of settings and data

## Not implemented (plans for future)

- Open loop mode
- Profile upload to Nightscout
- Home screen widget
- Apple Health support for carbs and insulin

## Community

- [English Telegram group](https://t.me/freeapsx_eng)
- [Russian Telegram group](https://t.me/freeapsx)
