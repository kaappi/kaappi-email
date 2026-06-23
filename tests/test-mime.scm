(import (scheme base) (scheme write)
        (kaappi email mime))

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

;; --- Base64 encoding ---

(display "Base64 encoding\n")

(check (base64-encode "") => "")
(check (base64-encode "f") => "Zg==")
(check (base64-encode "fo") => "Zm8=")
(check (base64-encode "foo") => "Zm9v")
(check (base64-encode "foobar") => "Zm9vYmFy")
(check (base64-encode "Hello, World!") => "SGVsbG8sIFdvcmxkIQ==")

;; --- Message construction ---

(display "Message construction\n")

(define msg (make-message "alice@example.com"
                          '("bob@example.com")
                          "Test Subject"
                          "Hello Bob!"))

(check-true (string? (message->string msg)))

(define msg-str (message->string msg))

(check-true (string-contains msg-str "From: alice@example.com"))
(check-true (string-contains msg-str "To: bob@example.com"))
(check-true (string-contains msg-str "Subject: Test Subject"))
(check-true (string-contains msg-str "MIME-Version: 1.0"))
(check-true (string-contains msg-str "Hello Bob!"))

;; --- Multiple recipients ---

(display "Multiple recipients\n")

(define msg2 (make-message "sender@test.com"
                           '("a@test.com" "b@test.com")
                           "Multi"
                           "body"))

(define msg2-str (message->string msg2))
(check-true (string-contains msg2-str "To: a@test.com, b@test.com"))

;; --- CC ---

(display "CC\n")

(define msg3 (make-message "sender@test.com"
                           '("to@test.com")
                           "With CC"
                           "body"
                           'cc '("cc@test.com")))

(define msg3-str (message->string msg3))
(check-true (string-contains msg3-str "Cc: cc@test.com"))

;; --- Helper: string-contains ---

(define (string-contains haystack needle)
  (let ((hlen (string-length haystack))
        (nlen (string-length needle)))
    (let loop ((i 0))
      (cond
        ((> (+ i nlen) hlen) #f)
        ((string=? (substring haystack i (+ i nlen)) needle) #t)
        (else (loop (+ i 1)))))))

;; --- Summary ---

(newline)
(display pass) (display " passed, ")
(display fail) (display " failed\n")
(when (> fail 0) (exit 1))
