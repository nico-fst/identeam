# Changelog

## [1.4.0+6] - 2026-04-15

### Added

- Creation of User Targets (not possible on iOS yet) and Idents (possible on iOS)
- TeamWeekView displaying status of team's current weekly progress
- iOS: animated LaunchScreen
- Backend Tests

### Refactored

- Added Wrapper for mapping objects to Data-Transfer-Objects
- Backend: Unified Error-Responses

### Changed

- 'NewIdent'-Notification now includes weekly progress, user's custom text and group's template

## [1.3.0+5] - 2026-04-09

### Added

- iOS: Team Creation

## [1.2.0+4] - 2026-03-07

### Added

- User Signup | Login via Email & Password

## [1.1.1+3] - 2026-03-04

### Changed

- iOS: Refactored ViewModels
- Made Login/Logout Process more robust

## [1.1.1] - 2025-01-13

### Fixed

- Prevent empty user.Username state in DB when signing up

## [1.1.0] - 2025-01-10

### Added

- Allow joining, leaving existing teams
- Simple 'Notify Team' Button
