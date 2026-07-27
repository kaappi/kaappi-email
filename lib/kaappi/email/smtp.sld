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

    ;; tcp-connect / tls-connect raise on failure, so a returned handle is
    ;; always live. The server greeting is consumed here so the first
    ;; command starts from a clean line.
    (define (smtp-connect host port)
      (let ((smtp (%make-smtp (tcp-connect host port) #f)))
        (smtp-read-response smtp)
        smtp))

    (define (smtp-connect-tls host port)
      (let ((smtp (%make-smtp (tls-connect host port) #t)))
        (smtp-read-response smtp)
        smtp))

    (define (smtp-close smtp)
      (smtp-quit smtp)
      (if (smtp-tls? smtp)
          (tls-close (smtp-conn smtp))
          (tcp-close (smtp-conn smtp))))

    ;; kaappi-net's transport works on caller-supplied bytevectors and byte
    ;; counts — (tcp-send conn buf len) / (tcp-recv conn buf len), raising
    ;; on socket errors — so strings are translated at this boundary. A
    ;; short send resumes with a copy of the unsent tail.
    (define (smtp-send smtp str)
      (let ((send-fn (if (smtp-tls? smtp) tls-send tcp-send))
            (conn (smtp-conn smtp)))
        (let loop ((bv (string->utf8 str)))
          (let* ((len (bytevector-length bv))
                 (n (send-fn conn bv len)))
            (when (< n len)
              (loop (bytevector-copy bv n)))))))

    (define recv-size 4096)

    (define (smtp-receive smtp)
      (let ((recv-fn (if (smtp-tls? smtp) tls-recv tcp-recv))
            (buf (make-bytevector recv-size 0)))
        (let ((n (recv-fn (smtp-conn smtp) buf recv-size)))
          (if (<= n 0) "" (utf8->string buf 0 n)))))

    (define (smtp-command smtp cmd)
      (smtp-send smtp (string-append cmd "\r\n"))
      (smtp-read-response smtp))

    ;; A reply is one or more "NNN-text" lines closed by an "NNN text" (or
    ;; bare "NNN") line — RFC 5321 section 4.2. Keep reading until that
    ;; final line arrives so multi-line EHLO replies and fragmented TCP
    ;; reads don't truncate the response. Returns (code . full-text), or
    ;; (0 . "") when the server closed the connection.
    (define (smtp-read-response smtp)
      (let loop ((acc ""))
        (let ((chunk (smtp-receive smtp)))
          (if (string=? chunk "")
              (if (string=? acc "") (cons 0 "") (cons (reply-code acc) acc))
              (let ((acc (string-append acc chunk)))
                (if (reply-complete? acc)
                    (cons (reply-code acc) acc)
                    (loop acc)))))))

    (define (reply-code text)
      (or (and (>= (string-length text) 3)
               (string->number (substring text 0 3)))
          0))

    (define (reply-complete? text)
      (let loop ((lines (complete-lines text)))
        (cond ((null? lines) #f)
              ((final-reply-line? (car lines)) #t)
              (else (loop (cdr lines))))))

    ;; The \n-terminated lines of text, \r\n stripped; a trailing partial
    ;; line is dropped.
    (define (complete-lines text)
      (let ((len (string-length text)))
        (let loop ((start 0) (i 0) (out '()))
          (cond ((= i len) (reverse out))
                ((char=? (string-ref text i) #\newline)
                 (let ((end (if (and (> i start)
                                     (char=? (string-ref text (- i 1)) #\return))
                                (- i 1)
                                i)))
                   (loop (+ i 1) (+ i 1) (cons (substring text start end) out))))
                (else (loop start (+ i 1) out))))))

    (define (final-reply-line? line)
      (and (>= (string-length line) 3)
           (char-numeric? (string-ref line 0))
           (char-numeric? (string-ref line 1))
           (char-numeric? (string-ref line 2))
           (or (= (string-length line) 3)
               (char=? (string-ref line 3) #\space))))

    (define (smtp-ehlo smtp domain)
      (smtp-command smtp (string-append "EHLO " domain)))

    ;; kaappi-net has no in-place TLS upgrade for an established socket, so
    ;; STARTTLS cannot be completed; failing loudly beats continuing in
    ;; plaintext on a session the server now expects to be encrypted.
    (define (smtp-starttls smtp)
      (error "smtp-starttls: not supported (kaappi-net cannot upgrade an open connection); use smtp-connect-tls"))

    (define (smtp-auth-plain smtp user pass)
      (let* ((creds (string-append "\x00;" user "\x00;" pass))
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

    (define (expect-code resp codes what)
      (if (memv (car resp) codes)
          resp
          (error (string-append "smtp: " what " rejected") resp)))

    ;; RFC 5321 section 4.5.2: a body line beginning with "." gets a
    ;; second "." prepended so it cannot terminate the DATA section. The
    ;; "." terminator also needs the body to end on a fresh line, so a
    ;; missing trailing newline gets one added.
    (define (dot-stuff content)
      (let ((out (open-output-string))
            (len (string-length content)))
        (let loop ((i 0) (bol #t))
          (if (= i len)
              (begin
                (unless (and (> len 0)
                             (char=? (string-ref content (- len 1)) #\newline))
                  (write-string "\r\n" out))
                (get-output-string out))
              (let ((c (string-ref content i)))
                (when (and bol (char=? c #\.))
                  (write-char #\. out))
                (write-char c out)
                (loop (+ i 1) (char=? c #\newline)))))))

    (define (smtp-data smtp content)
      (expect-code (smtp-command smtp "DATA") '(354) "DATA")
      (smtp-send smtp (dot-stuff content))
      (expect-code (smtp-command smtp ".") '(250) "message body"))

    (define (smtp-quit smtp)
      (smtp-command smtp "QUIT"))

    (define (smtp-send-message smtp msg)
      (let ((from (cdr (assoc "from" msg)))
            (recipients (all-recipients msg))
            (content (message->string msg)))
        (expect-code (smtp-mail-from smtp from) '(250) "MAIL FROM")
        (for-each
         (lambda (r)
           (expect-code (smtp-rcpt-to smtp r) '(250 251) "RCPT TO"))
         recipients)
        (smtp-data smtp content)))

    (define (all-recipients msg)
      (let ((to (cdr (assoc "to" msg)))
            (cc-pair (assoc "cc" msg)))
        (let ((cc (if cc-pair (cdr cc-pair) #f)))
          (append (if (list? to) to (list to))
                  (if (and cc (list? cc)) cc
                      (if cc (list cc) '()))))))))
