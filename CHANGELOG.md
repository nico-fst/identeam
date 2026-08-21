# Changelog
## [1.9.0+14] - 2026-08-21

### Fixed

- Race Condition when selecting team (refreshing own avatar deleted other)

## [1.9.0+13] - 2026-07-08

### Added

- Default seeded User Avatars using DiceBear
- Introducing Ident Comments
- Showing User Avatars in Teams

### Fixed

- Close SetTargetSheet after saving
- Add cooldown for reminding Team

## [1.8.0+12] - 2026-06-03

### Added

- Intelligent Reminders per team (every day) using mean of last Idents

## [1.7.0+11] - 2026-05-21

### Added

- Allow creating Idents via camera and upload to R2/S3

## [1.6.0+9] - 2026-05-09

### Added

- Usage of S3/R2 storage for media
- Allow uploading, changing of user avatars (profile pictures)

## [1.5.0+7] - 2026-04-17

### Added

- iOS: Creation of User Targets

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
