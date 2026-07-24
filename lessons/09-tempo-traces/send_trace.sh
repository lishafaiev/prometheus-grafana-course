#!/usr/bin/env bash
# Надсилає тестовий OTLP-трейс у Alloy (→ Tempo) через HTTP.
# Використання:
#   bash send_trace.sh                      # шле на http://localhost:4318 (port-forward Alloy)
#   bash send_trace.sh http://localhost:4318
set -euo pipefail

ENDPOINT="${1:-http://localhost:4318}"

# Свіжі таймінги в наносекундах (інакше трейс ляже в минуле й не знайдеться).
NOW_NS=$(date +%s%N)
END_NS=$((NOW_NS + 100000000))            # +100 мс тривалість спана

# Випадкові ідентифікатори: trace-id = 16 байт (32 hex), span-id = 8 байт (16 hex).
TRACE_ID=$(openssl rand -hex 16)
SPAN_ID=$(openssl rand -hex 8)

curl -sS -X POST "${ENDPOINT}/v1/traces" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": { "attributes": [
        { "key": "service.name", "value": { "stringValue": "demo-service" } }
      ]},
      "scopeSpans": [{
        "scope": { "name": "demo-tracer" },
        "spans": [{
          "traceId": "'"$TRACE_ID"'",
          "spanId": "'"$SPAN_ID"'",
          "name": "demo-span",
          "kind": 2,
          "startTimeUnixNano": "'"$NOW_NS"'",
          "endTimeUnixNano": "'"$END_NS"'",
          "attributes": [
            { "key": "http.method", "value": { "stringValue": "GET" } }
          ]
        }]
      }]
    }]
  }'

echo
echo "sent trace_id=$TRACE_ID to $ENDPOINT"
