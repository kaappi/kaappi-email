# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.1.0] - 2026-07-26

### Added
- SMTP email client — `send-email` and `make-message`, plus the lower-level
  `(kaappi email smtp)` session API (`smtp-connect`/`smtp-connect-tls`/
  `smtp-close`, `smtp-ehlo`, `smtp-auth-plain`/`smtp-auth-login`,
  `smtp-send-message`)
- MIME message support via `(kaappi email mime)`
- `base64-encode` helper
- Pure Scheme, built on kaappi-net for TCP/TLS
- CI workflow for automated testing
