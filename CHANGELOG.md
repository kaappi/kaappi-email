# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- SMTP transport never worked: `smtp-send`/`smtp-receive` called
  kaappi-net's `tcp-send`/`tcp-recv`/`tls-send`/`tls-recv` with the wrong
  arity (2 args, string payloads) where the real API is `(fn conn buf len)`
  over bytevectors returning byte counts — the first `smtp-connect` raised
  an arity error before any bytes moved
- `smtp-read-response` reassembles multi-line replies (EHLO) and
  fragmented TCP reads instead of assuming one recv returns one complete
  reply
- `smtp-data` dot-stuffs the message body (RFC 5321 section 4.5.2),
  guarantees the terminator lands on a fresh line, and verifies the
  354/250 responses; `smtp-send-message` now raises when the server
  rejects MAIL FROM or RCPT TO instead of silently continuing
- `smtp-starttls` raises a clear "not supported" error instead of
  pretending to upgrade and corrupting the session (kaappi-net has no
  in-place TLS upgrade; use `smtp-connect-tls`)

### Added
- Live SMTP round-trip regression test (`tests/test-smtp-roundtrip.sh`):
  a local Python sink accepts a real send, and the test asserts on the
  captured message; wired into CI

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
