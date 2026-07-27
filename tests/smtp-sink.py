#!/usr/bin/env python3
"""Minimal SMTP sink for the round-trip test (test-smtp-roundtrip.sh).

Speaks just enough RFC 5321 to accept a message: a multi-line EHLO reply
(exercises the client's reply reassembly), DATA dot-unstuffing like a
real server, and a capture file (argv[2]) rewritten with the body of the
most recent message. Serves sessions until killed.

Usage: smtp-sink.py <port> <capture-file>
"""
import socketserver
import sys


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        def send(line):
            self.wfile.write((line + "\r\n").encode())
            self.wfile.flush()

        send("220 sink ESMTP")
        data_mode, buf = False, []
        while True:
            raw = self.rfile.readline()
            if not raw:
                return
            line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
            if data_mode:
                if line == ".":
                    data_mode = False
                    with open(sys.argv[2], "w") as f:
                        f.write("\n".join(buf) + "\n")
                    send("250 OK stored")
                else:
                    # un-stuff: ".." lead-in was a body line starting with "."
                    buf.append(line[1:] if line.startswith("..") else line)
            else:
                cmd = line.upper()
                if cmd.startswith(("EHLO", "HELO")):
                    self.wfile.write(b"250-sink\r\n250-8BITMIME\r\n")
                    send("250 OK")
                elif cmd.startswith("DATA"):
                    send("354 end data with <CRLF>.<CRLF>")
                    data_mode = True
                elif cmd.startswith("QUIT"):
                    send("221 bye")
                    return
                else:
                    send("250 OK")


socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
