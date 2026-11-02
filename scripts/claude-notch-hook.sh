#!/bin/sh
# Forwards a Claude Code hook event (JSON on stdin) to the Notchhaven app.
# Fails silently if the app is not running or the feature is off.
curl -s -m 2 -X POST "http://127.0.0.1:26540/event" \
  -H "X-Notchhaven-Client: claude-hook" \
  --data-binary @- >/dev/null 2>&1 || true
exit 0
