#!/usr/bin/env bash
# 로컬 MySQL: godoksa_db + team_user 생성
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL="$ROOT/src/main/resources/db/init-local.sql"

echo "== 하루신호 DB 설정 =="
echo "대상: localhost:3306 / godoksa_db / team_user"
echo ""

if command -v docker >/dev/null 2>&1; then
  echo "[1] Docker로 MySQL 기동..."
  cd "$ROOT"
  docker compose up -d
  echo "컨테이너 준비 대기..."
  for i in $(seq 1 30); do
    if docker compose exec -T mysql mysqladmin ping -h 127.0.0.1 -uroot -proot --silent 2>/dev/null; then
      echo "Docker MySQL 준비 완료 (init 스크립트는 이미 env로 DB/유저 생성됨)"
      echo ""
      echo "다음: ./gradlew bootRun  (테이블 자동 생성)"
      exit 0
    fi
    sleep 2
  done
  echo "Docker MySQL 대기 실패 — docker compose logs mysql"
  exit 1
fi

if ! command -v mysql >/dev/null 2>&1; then
  echo "mysql 클라이언트가 없습니다."
  echo "  - Docker Desktop 설치 후: docker compose up -d"
  echo "  - 또는: brew install mysql"
  exit 1
fi

echo "[1] Homebrew MySQL 사용"
if command -v brew >/dev/null 2>&1; then
  if ! brew services list 2>/dev/null | grep -q "mysql.*started"; then
    echo "MySQL 서비스 시작 시도: brew services start mysql"
    brew services start mysql 2>/dev/null || true
    sleep 3
  fi
fi

echo "[2] DB·사용자 생성 (root 비밀번호 입력 필요할 수 있음)"
echo "    파일: $SQL"
echo ""

if mysql -u root < "$SQL" 2>/dev/null; then
  OK=1
elif mysql -u root -p < "$SQL"; then
  OK=1
else
  OK=0
fi

if [ "${OK:-0}" -eq 1 ]; then
  echo ""
  echo "연결 테스트..."
  if mysql -u team_user -pteam1234! -h 127.0.0.1 godoksa_db -e "SELECT DATABASE() AS db, USER() AS user;"; then
    echo ""
    echo "완료. 다음 단계:"
    echo "  cd $ROOT"
    echo "  ./gradlew bootRun    # JPA가 users, device, activity_log 등 테이블 생성"
    exit 0
  fi
fi

echo ""
echo "자동 설정에 실패했습니다. 수동 실행:"
echo "  mysql -u root -p < src/main/resources/db/init-local.sql"
echo ""
echo "application.properties 와 동일해야 합니다:"
echo "  DB: godoksa_db  user: team_user  password: team1234!"
