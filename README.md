# kaappi-email

SMTP email client for [Kaappi Scheme](https://github.com/kaappi/kaappi).

## Install

```bash
thottam install kaappi-email
```

This also installs `kaappi-net` (TCP/TLS networking).

## Quick start

```scheme
(import (kaappi email))

;; Send via Gmail (TLS on port 465)
(send-email "smtp.gmail.com" 465
  "you@gmail.com"
  '("recipient@example.com")
  "Hello from Kaappi!"
  "This email was sent from Kaappi Scheme."
  'tls #t
  'user "you@gmail.com"
  'password "your-app-password"
  'domain "gmail.com")
```

## API

### High-level

```scheme
(send-email host port from to subject body [options...])
```

**Options** (keyword-style):
- `'tls #t` — use SMTPS (TLS on connect, port 465)
- `'user "..."` — SMTP username for AUTH PLAIN
- `'password "..."` — SMTP password
- `'domain "..."` — EHLO domain (default: "localhost")
- `'cc '("addr" ...)` — CC recipients

### Message construction

```scheme
(make-message from to subject body [options...])
(message->string msg)    ; render to RFC 2822 MIME string
```

The `to` field accepts a single address or a list. Options: `'cc`, `'reply-to`, `'content-type`.

### Low-level SMTP

```scheme
(smtp-connect host port)        ; plain TCP
(smtp-connect-tls host port)    ; TLS (SMTPS)
(smtp-ehlo smtp domain)
(smtp-auth-plain smtp user pass)
(smtp-auth-login smtp user pass)
(smtp-send-message smtp msg)    ; full MAIL FROM/RCPT TO/DATA sequence
(smtp-close smtp)
```

### Utilities

```scheme
(base64-encode string)   ; base64 encoding (for AUTH, attachments)
```

## Sub-libraries

- `(kaappi email)` — high-level `send-email` (requires kaappi-net)
- `(kaappi email mime)` — message construction + base64 (no network deps)
- `(kaappi email smtp)` — low-level SMTP protocol (requires kaappi-net)

## License

MIT
