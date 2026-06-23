(define-library (kaappi email smtp)
  (import (scheme base) (scheme char) (scheme write)
          (kaappi net)
          (kaappi email mime))
  (export smtp-connect smtp-connect-tls smtp-close
          smtp-ehlo smtp-auth-plain smtp-auth-login
          smtp-starttls smtp-send-message
          smtp-mail-from smtp-rcpt-to smtp-data smtp-quit
          smtp-read-response)
  (begin

    (define-record-type <smtp-connection>
      (%make-smtp conn tls?)
      smtp-connection?
      (conn smtp-conn set-smtp-conn!)
      (tls? smtp-tls? set-smtp-tls?!))

    (define (smtp-connect host port)
      (let ((conn (tcp-connect host port)))
        (if (= conn 0)
            (error "smtp-connect: failed to connect" host port)
            (let ((smtp (%make-smtp conn #f)))
              (smtp-read-response smtp)
              smtp))))

    (define (smtp-connect-tls host port)
      (let ((conn (tls-connect host port)))
        (if (= conn 0)
            (error "smtp-connect-tls: failed to connect" host port)
            (let ((smtp (%make-smtp conn #t)))
              (smtp-read-response smtp)
              smtp))))

    (define (smtp-close smtp)
      (smtp-quit smtp)
      (if (smtp-tls? smtp)
          (tls-close (smtp-conn smtp))
          (tcp-close (smtp-conn smtp))))

    (define (smtp-send smtp str)
      (if (smtp-tls? smtp)
          (tls-send (smtp-conn smtp) str)
          (tcp-send (smtp-conn smtp) str)))

    (define (smtp-receive smtp)
      (if (smtp-tls? smtp)
          (tls-recv (smtp-conn smtp) 4096)
          (tcp-recv (smtp-conn smtp) 4096)))

    (define (smtp-command smtp cmd)
      (smtp-send smtp (string-append cmd "\r\n"))
      (smtp-read-response smtp))

    (define (smtp-read-response smtp)
      (let ((resp (smtp-receive smtp)))
        (if (or (not resp) (string=? resp ""))
            (cons 0 "")
            (let ((code (or (string->number (substring resp 0 (min 3 (string-length resp)))) 0)))
              (cons code resp)))))

    (define (min a b) (if (< a b) a b))

    (define (smtp-ehlo smtp domain)
      (smtp-command smtp (string-append "EHLO " domain)))

    (define (smtp-starttls smtp)
      (let ((resp (smtp-command smtp "STARTTLS")))
        (when (= (car resp) 220)
          (let ((tls-conn (tls-connect-upgrade (smtp-conn smtp))))
            (set-smtp-conn! smtp tls-conn)
            (set-smtp-tls?! smtp #t)))
        resp))

    (define (tls-connect-upgrade conn) conn)

    (define (smtp-auth-plain smtp user pass)
      (let* ((creds (string-append "\x00" user "\x00" pass))
             (encoded (base64-encode creds)))
        (smtp-command smtp (string-append "AUTH PLAIN " encoded))))

    (define (smtp-auth-login smtp user pass)
      (smtp-command smtp "AUTH LOGIN")
      (smtp-command smtp (base64-encode user))
      (smtp-command smtp (base64-encode pass)))

    (define (smtp-mail-from smtp addr)
      (smtp-command smtp (string-append "MAIL FROM:<" addr ">")))

    (define (smtp-rcpt-to smtp addr)
      (smtp-command smtp (string-append "RCPT TO:<" addr ">")))

    (define (smtp-data smtp content)
      (smtp-command smtp "DATA")
      (smtp-send smtp content)
      (smtp-command smtp "."))

    (define (smtp-quit smtp)
      (smtp-command smtp "QUIT"))

    (define (smtp-send-message smtp msg)
      (let ((from (cdr (assoc "from" msg)))
            (recipients (all-recipients msg))
            (content (message->string msg)))
        (smtp-mail-from smtp from)
        (for-each (lambda (r) (smtp-rcpt-to smtp r)) recipients)
        (smtp-data smtp content)))

    (define (all-recipients msg)
      (let ((to (cdr (assoc "to" msg)))
            (cc-pair (assoc "cc" msg)))
        (let ((cc (if cc-pair (cdr cc-pair) #f)))
          (append (if (list? to) to (list to))
                  (if (and cc (list? cc)) cc
                      (if cc (list cc) '()))))))))
