(import (kaappi email mime))
;; For sending: (import (kaappi email))

;; Example: send an email via SMTP with authentication
;;
;; (send-email "smtp.gmail.com" 465
;;   "you@gmail.com"
;;   '("recipient@example.com")
;;   "Hello from Kaappi!"
;;   "This email was sent from Kaappi Scheme."
;;   'tls #t
;;   'user "you@gmail.com"
;;   'password "your-app-password"
;;   'domain "gmail.com")

;; Example: construct a message without sending
(define msg (make-message
  "alice@example.com"
  '("bob@example.com" "charlie@example.com")
  "Meeting Tomorrow"
  "Hi team,\n\nReminder: meeting at 10am.\n\nBest,\nAlice"
  'cc '("manager@example.com")))

(display "Generated MIME message:\n")
(display "---\n")
(display (message->string msg))
(display "---\n")
