#!/usr/bin/env bash
# =========================================================
# run-flutter-ngrok.sh
# 현재 실행 중인 ngrok URL을 자동으로 읽어서
# Flutter 앱을 ngrok 주소로 바로 실행합니다.
#
# 전제 조건:
#   1. ngrok이 실행 중이어야 합니다 (start-ngrok.sh로 먼저 실행)
#   2. Spring Boot가 실행 중이어야 합니다 (./gradlew bootRun)
# =========================================================

FLUTTER_DIR="$(cd "$(dirname "$0")/../app" && pwd)"

# ngrok에서 현재 HTTPS URL 읽기
echo "🔍 ngrok URL 조회 중..."
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null \
  | python3 -c "import sys,json; tunnels=json.load(sys.stdin).get('tunnels',[]); print([t['public_url'] for t in tunnels if t['public_url'].startswith('https')][0])" 2>/dev/null)

if [ -z "$NGROK_URL" ]; then
  echo "❌ 실행 중인 ngrok 터널을 찾을 수 없습니다."
  echo "   먼저 ./scripts/start-ngrok.sh 를 실행하세요."
  exit 1
fi

echo ""
echo "✅ ngrok URL 확인: $NGROK_URL"
echo "📱 Flutter 앱 실행 중..."
echo ""

cd "$FLUTTER_DIR" && flutter run --dart-define=API_BASE_URL="$NGROK_URL"
