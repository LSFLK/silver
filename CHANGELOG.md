# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - Raven Integration and Platform Hardening

This release introduces Raven-based mail architecture, major security and
observability improvements, and stronger operational tooling.

### Added

- Raven delivery integration and related configuration updates
  (`#120`, `#121`, `#123`).
- Role-based mail system support (`#164`).
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
- Updated Thunder integration to version `0.14.0` (`#191`).
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

### What's Changed

- Docker services init. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/16
- Tests for SMTP local delivery from host machine to container. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/17
- Feat/swag setup by @maneeshaxyz in https://github.com/LSFLK/silver/pull/18
- chore: docs. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/19
- Chore/combined containers by @maneeshaxyz in https://github.com/LSFLK/silver/pull/21
- Chore/env change by @maneeshaxyz in https://github.com/LSFLK/silver/pull/22
- M1: base functionality is completed by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/27
- Feat/init scripts by @maneeshaxyz in https://github.com/LSFLK/silver/pull/28
- Feat/init scripts by @maneeshaxyz in https://github.com/LSFLK/silver/pull/29
- Chore/docs by @maneeshaxyz in https://github.com/LSFLK/silver/pull/30
- Feat/webui by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/31
- Scripts and simple webui to run the mail server by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/32
- Refactor/docs by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/34
- Refactor/docs and Update webui by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/35
- docs: fixes. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/36
- Docs/doc-fixes. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/37
- Refactor/ymal file by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/39
- chore: added yaml parsing in init.sh. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/40
- chore: fix add user init script by @maneeshaxyz in https://github.com/LSFLK/silver/pull/41
- Feat/load test by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/42
- fix: combined the add_user files and use only minimum details by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/43
- feat: add quota limit for mail dir by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/44
- Refactor/thunder endpoints by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/45
- Refactor/thunder endpoints by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/47
- Feat/user list by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/48
- Feat/switch to yaml file across services. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/38
- chore: docs-merge-fixes by @maneeshaxyz in https://github.com/LSFLK/silver/pull/55
- chore: fix docs. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/56
- Merge the dev branch into main by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/57
- 51 restrict external access to thunder idp by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/58
- 50 enable pop3 access while keeping a copy of emails on the server by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/65
- 49 enable adding virtual users without rebuilding postfix container by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/61
- Dynamic Mail User Provisioning with POP3 Protocol Support by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/66
- Feat/issue template by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/68
- feat: add pull request template for improved contribution guidelines by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/69
- 70 task switch to a light weight base image by @maneeshaxyz in https://github.com/LSFLK/silver/pull/75
- Feat/service-cleanup by @maneeshaxyz in https://github.com/LSFLK/silver/pull/64
- chore: fix receiving lmtp. by @maneeshaxyz in https://github.com/LSFLK/silver/pull/78
- Fix by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/79
- chore: change maillog_file path to stdout for Docker compatibility by @Aravinda-HWK in https://github.com/LSFLK/silver/pull/81
- 71 task audit dockerfiles by @maneeshaxyz in https://github.com/LSFLK/silver/pull/83
- Merge main into dev by @maneeshaxyz in https://github.com/LSFLK/silver/pull/85

### Full Changelog

https://github.com/LSFLK/silver/commits/v0.1.0
