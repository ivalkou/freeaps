# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] - 2026-02-01

### Added
- **Apple Health insulin integration**: Sync bolus and basal insulin delivery to Apple Health
- **Insulin recommendation tracking**: Store and display recommended insulin amount alongside actual bolus in treatment history
- **Carbs notes**: Add ability to include notes when entering carbohydrates
- **Manual glucose entry**: Add glucose readings manually from the app
- **Daily automatic backup**: Configure automatic daily backups with customizable time and retention period
- **Tuist project generation**: Migrate build system to Tuist for easier project management

### Changed
- Improved App Group configuration for device builds
- Updated minimum iOS target to 15.0

### Removed
- Non-functional share button from backup settings

### Fixed
- Device build issues with App Group configuration
- Build system cycle errors (Xcode 13.3+)

## [0.2.6] and earlier

See git history for previous changes.
