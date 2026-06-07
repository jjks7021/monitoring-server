#!/usr/bin/env bash
# Crisis(위험 알림) 생성 + 상태 확인용 스크립트
# 사용: ./scripts/test-crisis-flow.sh <toilet|lethargy|status> <LOGIN_CODE> [HARDWARE_ID] [BASE_URL]
set -euo pipefail

MODE="${1:?mode: toilet | lethargy | status}"
CODE="${2:?6자리 loginCode 필요}"
HW_ID="${3:-test-hardware-$(date +%s)}"
BASE="${4:-http://127.0.0.1:8080}"

json_post() {
  local path="$1"
  local body="$2"
  curl -s -X POST "${BASE}${path}" \
    -H "Content-Type: application/json" \
    -d "$body"
}

register_if_needed() {
  json_post "/api/devices/register" "{\"hardwareId\":\"${HW_ID}\",\"loginCode\":\"${CODE}\"}" >/dev/null || true
}

send_coords() {
  local x="$1" y="$2" z="$3" tag="$4" dur="${5:-0}"
  json_post "/api/devices/coordinates" \
    "{\"loginCode\":\"${CODE}\",\"hardwareId\":\"${HW_ID}\",\"x\":${x},\"y\":${y},\"z\":${z},\"locationTag\":\"${tag}\",\"currentDuration\":${dur}}"
}

case "$MODE" in
  toilet)
    echo "== 화장실 Crisis 유도 (currentDuration=65, 평소 20분×3 초과) =="
    register_if_needed
    RESP=$(send_coords 150 250 8 "TOILET" 65)
    echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
    ;;
  lethargy)
    echo "== 무기력 Crisis 유도 (동일 좌표 12회) =="
    register_if_needed
    for i in $(seq 1 12); do
      RESP=$(send_coords 100 200 5 "ROOM" 0)
      echo "[$i] activeCrises=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('activeCrises',[]))" 2>/dev/null || echo '?')"
      sleep 0.3
    done
    echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
    ;;
  status)
    echo "== 활성 Crisis =="
    curl -s "${BASE}/api/crisis/active?loginCode=${CODE}" | python3 -m json.tool
    echo ""
    echo "== 최신 AI 위험 =="
    curl -s -w "\nHTTP %{http_code}\n" "${BASE}/api/risk/latest/${CODE}" | head -20
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac

echo ""
echo "다음: 보호자 앱 홈 → 알림 탭 확인 → Crisis 있으면 「긴급 실시간 사진 요청」"
