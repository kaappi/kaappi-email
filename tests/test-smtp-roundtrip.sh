#!/bin/bash
# SMTP round-trip test — starts the Python sink, runs the Scheme client
# against it, and lets the Scheme side assert on the captured message.
#
#   KAAPPI    kaappi binary (default: kaappi on PATH)
#   LIB_PATH  this repo's lib/ (default: lib)
#   NET_LIB   kaappi-net's lib/, when kaappi-net isn't installed
set +e

KAAPPI="${KAAPPI:-kaappi}"
LIB_PATH="${LIB_PATH:-lib}"
PORT="${SMTP_SINK_PORT:-12525}"
DIR="$(cd "$(dirname "$0")" && pwd)"
CAPTURE="$(mktemp "${TMPDIR:-/tmp}/smtp-capture.XXXXXX")"

NET_ARGS=()
[ -n "$NET_LIB" ] && NET_ARGS=(--lib-path "$NET_LIB")

python3 "$DIR/smtp-sink.py" "$PORT" "$CAPTURE" &
SINK_PID=$!
cleanup() { kill $SINK_PID 2>/dev/null; wait $SINK_PID 2>/dev/null; rm -f "$CAPTURE"; true; }
trap cleanup EXIT

# Wait for the sink to listen
for _ in $(seq 1 50); do
    python3 - "$PORT" <<'EOF' && break
import socket, sys
s = socket.socket()
s.settimeout(0.2)
try:
    s.connect(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
s.close()
EOF
    sleep 0.1
done

SMTP_SINK_PORT="$PORT" SMTP_CAPTURE="$CAPTURE" \
    "$KAAPPI" "${NET_ARGS[@]}" --lib-path "$LIB_PATH" "$DIR/test-smtp-roundtrip.scm"
RC=$?

kill $SINK_PID 2>/dev/null; wait $SINK_PID 2>/dev/null
trap - EXIT
rm -f "$CAPTURE"
exit $RC
