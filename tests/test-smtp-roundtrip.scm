;; Live SMTP round-trip against tests/smtp-sink.py — run via
;; tests/test-smtp-roundtrip.sh, which starts the sink and sets
;; SMTP_SINK_PORT / SMTP_CAPTURE. Without them (e.g. under the plain
;; tests/*.scm loop) this file skips, so it stays green with no sink.
;;
;; This is the test the arity bug proved necessary: smtp.sld once called
;; kaappi-net's 3-argument tcp-send/tcp-recv with 2 arguments, so the
;; library loaded fine but crashed on the first real connection. Only a
;; test that moves bytes through a socket can catch that class.
(import (scheme base) (scheme write) (scheme file)
        (scheme process-context)
        (kaappi email)
        (kaappi email mime)
        (kaappi email smtp))

(define sink-port
  (let ((p (get-environment-variable "SMTP_SINK_PORT")))
    (and p (string->number p))))

(define capture-path (get-environment-variable "SMTP_CAPTURE"))

(unless (and sink-port capture-path)
  (display "SKIP: SMTP_SINK_PORT/SMTP_CAPTURE not set (no sink running)\n")
  (exit 0))

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

(define (read-all path)
  (call-with-input-file path
    (lambda (port)
      (let loop ((out ""))
        (let ((line (read-line port)))
          (if (eof-object? line)
              out
              (loop (string-append out line "\n"))))))))

(define (contains? hay needle)
  (let ((hl (string-length hay)) (nl (string-length needle)))
    (let loop ((i 0))
      (cond ((> (+ i nl) hl) #f)
            ((string=? (substring hay i (+ i nl)) needle) #t)
            (else (loop (+ i 1)))))))

;; --- send-email: the documented quick-start flow ---

(display "send-email round trip\n")

;; define wrappers keep non-unspecified return values out of the output
(define send-email-result
  (send-email "127.0.0.1" sink-port
    "test@localhost" '("dev@localhost")
    "Round Trip" "Hello from the regression test."))

(define captured-1 (read-all capture-path))
(check-true (contains? captured-1 "From: test@localhost"))
(check-true (contains? captured-1 "To: dev@localhost"))
(check-true (contains? captured-1 "Subject: Round Trip"))
(check-true (contains? captured-1 "Hello from the regression test."))

;; --- low-level session: multi-line EHLO reply, dot-stuffed body ---

(display "low-level session\n")

(define smtp (smtp-connect "127.0.0.1" sink-port))
(define ehlo-resp (smtp-ehlo smtp "localhost"))
(check (car ehlo-resp) => 250)
;; the sink replies "250-sink / 250-8BITMIME / 250 OK"; seeing the middle
;; line proves the multi-line reply was reassembled, not truncated
(check-true (contains? (cdr ehlo-resp) "8BITMIME"))

(define msg
  (make-message "from@localhost" '("to@localhost")
                "Dots" "first line\r\n.\r\nsurvives a lone dot line"))
(define send-message-result (smtp-send-message smtp msg))
(define close-result (smtp-close smtp))

(define captured-2 (read-all capture-path))
(check-true (contains? captured-2 "Subject: Dots"))
;; without dot-stuffing the lone "." body line terminates DATA early and
;; everything after it leaks into the command stream
(check-true (contains? captured-2 "survives a lone dot line"))

;; --- Summary ---

(newline)
(display pass) (display " passed, ")
(display fail) (display " failed\n")
(when (> fail 0) (exit 1))
