(define-library (kaappi email)
  (import (scheme base)
          (kaappi email mime)
          (kaappi email smtp))
  (export send-email make-message
          smtp-connect smtp-connect-tls smtp-close
          smtp-ehlo smtp-auth-plain smtp-auth-login
          smtp-send-message
          base64-encode)
  (begin

    (define (send-email host port from to subject body . opts)
      (let* ((use-tls (get-opt opts 'tls #f))
             (user (get-opt opts 'user #f))
             (pass (get-opt opts 'password #f))
             (domain (get-opt opts 'domain "localhost"))
             (cc (get-opt opts 'cc #f))
             (smtp (if use-tls
                       (smtp-connect-tls host port)
                       (smtp-connect host port)))
             (msg (if cc
                      (make-message from to subject body 'cc cc)
                      (make-message from to subject body))))
        (smtp-ehlo smtp domain)
        (when (and user pass)
          (smtp-auth-plain smtp user pass))
        (smtp-send-message smtp msg)
        (smtp-close smtp)))

    (define (get-opt opts key default)
      (let loop ((rest opts))
        (cond
          ((null? rest) default)
          ((and (pair? rest) (pair? (cdr rest)) (eq? (car rest) key))
           (cadr rest))
          ((pair? rest) (loop (cdr rest)))
          (else default))))))
