;; Imports every library in this package so that a file that fails to
;; read (e.g. a bad escape sequence in a string literal) breaks the test
;; suite instead of shipping silently. Add new libraries here when they
;; are added under lib/.
(import (scheme base) (scheme write)
        (kaappi email)
        (kaappi email mime)
        (kaappi email smtp))

(define pass 0)
(define fail 0)

(define-syntax check
  (syntax-rules (=>)
    ((_ expr => expected)
     (let ((result expr) (exp expected))
       (if (equal? result exp)
           (set! pass (+ pass 1))
           (begin
             (set! fail (+ fail 1))
             (display "FAIL: ") (write 'expr)
             (display " => ") (write result)
             (display ", expected ") (write exp)
             (newline)))))))

(define-syntax check-true
  (syntax-rules ()
    ((_ expr)
     (if expr (set! pass (+ pass 1))
         (begin (set! fail (+ fail 1))
                (display "FAIL: ") (write 'expr)
                (display " is false\n"))))))

;; --- All exported procedures are bound ---

(display "Exports\n")

(check-true (procedure? send-email))
(check-true (procedure? make-message))
(check-true (procedure? message->string))
(check-true (procedure? base64-encode))
(check-true (procedure? smtp-connect))
(check-true (procedure? smtp-connect-tls))
(check-true (procedure? smtp-close))
(check-true (procedure? smtp-ehlo))
(check-true (procedure? smtp-auth-plain))
(check-true (procedure? smtp-auth-login))
(check-true (procedure? smtp-starttls))
(check-true (procedure? smtp-send-message))
(check-true (procedure? smtp-mail-from))
(check-true (procedure? smtp-rcpt-to))
(check-true (procedure? smtp-data))
(check-true (procedure? smtp-quit))
(check-true (procedure? smtp-read-response))

;; --- AUTH PLAIN credential encoding (RFC 4616: NUL user NUL pass) ---
;; Same string construction as smtp-auth-plain; guards the "\x00;" NUL
;; escapes and base64 handling of NUL bytes.

(display "AUTH PLAIN credentials\n")

(check (string-length (string-append "\x00;" "user" "\x00;" "pass")) => 10)
(check (base64-encode (string-append "\x00;" "user" "\x00;" "pass"))
       => "AHVzZXIAcGFzcw==")

;; --- Summary ---

(newline)
(display pass) (display " passed, ")
(display fail) (display " failed\n")
(when (> fail 0) (exit 1))
