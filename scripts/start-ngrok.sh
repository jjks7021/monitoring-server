#!/usr/bin/env bash
# =========================================================
# start-ngrok.sh
# Spring Boot 포트(8080)를 ngrok으로 외부에 노출합니다.
# 실행 후 출력된 HTTPS URL을 Flutter 앱 실행 시 사용하세요.
# =========================================================

PORT=8080

# 이미 실행 중인 ngrok이 있으면 종료
if pgrep -x "ngrok" > /dev/null; then
  echo "⚠️  이미 실행 중인 ngrok을 종료합니다..."
  pkill -x ngrok
  sleep 1
fi

echo "🚀 ngrok 시작 중 (포트 $PORT)..."
ngrok http $PORT > /dev/null 2>&1 &

# ngrok API가 준비될 때까지 대기
echo "⏳ ngrok 터널 대기 중..."
for i in {1..15}; do
  NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null \
    | python3 -c "import sys,json; tunnels=json.load(sys.stdin).get('tunnels',[]); print([t['public_url'] for t in tunnels if t['public_url'].startswith('https')][0])" 2>/dev/null)
  if [ -n "$NGROK_URL" ]; then
    break
  fi
  sleep 1
done

if [ -z "$NGROK_URL" ]; then
  echo "❌ ngrok URL을 가져오지 못했습니다. 직접 http://localhost:4040 에서 확인하세요."
  exit 1
fi

echo ""
echo "✅ ngrok 터널 활성!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌐 외부 URL : $NGROK_URL"
echo "  📊 ngrok 대시보드 : http://localhost:4040"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Flutter 실행 명령어:"
echo "  cd app"
echo "  flutter run --dart-define=API_BASE_URL=$NGROK_URL"
echo ""
echo "또는 자동 실행:"
echo "  ./scripts/run-flutter-ngrok.sh"
