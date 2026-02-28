# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1]

This release focuses on making improvements to the observability of silver.

## What's Changed
### Added
* Update thunder idp to latest version to support admin initiated user registration via url flow by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/265
* Move observability services into mail stack and update configur… by @maneeshaxyz in https://github.com/LSFLK/silver/pull/264
* Add Grafana domain update functionality in gen-observability script by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/275

### Removed
* Remove Change Password UI by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/267

### Fixed
* Fix observability bugs by @maneeshaxyz in https://github.com/LSFLK/silver/pull/270
* Fixed the issue of not saving the attachments in the blob storage. by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/268
* Fix observability port issue by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/273
* Loki not working correctly issue resolved. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/277
* Secure the rspamd web UI dashboard by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/279

**Full Changelog**: https://github.com/LSFLK/silver/compare/v.0.2.0...v.0.2.1

## [0.2.0] - Raven Integration and Platform Hardening

This release introduces Raven-based mail architecture, major security and
observability improvements, and stronger operational tooling.

### Added

- Raven delivery integration and related configuration updates
  (`#120`, `#121`, `#123`).
- Change password Web UI and backend services (`#201`, `#203`, `#206`, `#207`).
- Load testing suite, utilities, and CI jobs (`#211`, `#213`, `#215`, `#229`,
  `#230`, `#232`, `#234`).
- Observability stack with Prometheus, Loki, Promtail, and Grafana dashboards
  (`#173`, `#174`, `#178`, `#181`, `#183`, `#184`, `#186`, `#188`, `#190`,
  `#198`).
- Smart attachment/blob storage support (`#238`).
- Docker cleanup and service control scripting improvements (`#121`, `#133`).

### Changed

- Replaced Dovecot-based authentication and retrieval flows with Raven services
  and database-backed transport (`#138`, `#141`, `#152`).
- Migrated service configuration layout and script paths toward `conf/` and YAML
  driven generation (`#129`, `#137`).
- Improved container build/push workflows and integrated image scanning
  refinements (`#131`, `#144`).
- Enhanced multi-domain certificate/domain handling and DKIM script workflows
  (`#157`, `#158`).
- Removed Unix socket usage from core Silver services (`#236`).

### Fixed

- Resolved ClamAV daily refresh OOM issues (`#143`).
- Removed OCSP stapling configuration that caused compatibility issues (`#168`).
- Corrected detect-changes workflow repository filtering (`#217`).
- Fixed multiple script/config path issues in setup and documentation (`#129`,
  `#137`, `#246`).
- Fixed warning output in Docker containers (`#242`).

### Security

- Increased TLS hardening and added automated TLS security tests (`#166`).
- Removed unnecessary exposed ports for internal services, including SeaweedFS
  hardening (`#141`, `#243`).
- Added centralized ClamAV signature distribution and service cleanup (`#241`,
  `#245`).
- Removed encrypted password exposure in rspamd-related flow (`#176`).

### Documentation

- Expanded and improved README content, badges, and release docs (`#159`, `#225`,
  `#226`, `#234`, `#247`, `#248`).
- Refined contribution and repository guidance docs (`#160`, `#161`).

### Full Changelog

https://github.com/LSFLK/silver/compare/v0.1.0...v0.2.0

## [0.1.0] - First Stable Silver M1 Release

This release saves a stable working version of Silver M1 before integrating
Raven into the repository.

### Added

- Initial Dockerized Silver M1 services and SMTP host-to-container delivery
  testing (`#16`, `#17`, `#27`).
- Initial API/Web UI setup and operation scripts for running the mail server
  (`#18`, `#31`, `#32`).
- Bootstrap/init automation and user-facing tooling, including user listing and
  quota controls (`#28`, `#29`, `#44`, `#48`).
- Load testing support and related tooling (`#42`).
- Dynamic virtual user provisioning with POP3 support (`#61`, `#65`, `#66`).
- Repository collaboration templates for issues and pull requests (`#68`,
  `#69`).

### Changed

- Consolidated container layout, improved environment defaults, and completed
  service cleanup/hardening (`#21`, `#22`, `#64`, `#75`, `#83`).
- Migrated service configuration toward YAML-driven flows and parsing (`#38`,
  `#39`, `#40`).
- Refactored Thunder endpoints and restricted external access to Thunder IDP
  (`#45`, `#47`, `#58`).
- Updated runtime/logging behavior for Docker compatibility and merged long-lived
  branches to stabilize the release line (`#57`, `#81`, `#85`).
- Expanded and refined project documentation (`#19`, `#30`, `#34`, `#35`,
  `#36`, `#37`, `#55`, `#56`).

### Fixed

- Fixed user initialization and add-user script behavior (`#41`, `#43`).
- Fixed LMTP mail receiving flow and other release-blocking defects (`#78`,
  `#79`).

### Full Changelog

https://github.com/LSFLK/silver/releases/tag/v0.1.0
