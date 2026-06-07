#!/usr/bin/env bash
# 로컬 MySQL 기동 (Docker)
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker가 필요합니다. https://www.docker.com/products/docker-desktop/"
  exit 1
fi
docker compose up -d
echo "MySQL 대기 중..."
for i in $(seq 1 30); do
  if docker compose exec -T mysql mysqladmin ping -h 127.0.0.1 -uroot -proot --silent 2>/dev/null; then
    echo "MySQL 준비 완료 (localhost:3306 / godoksa_db)"
    exit 0
  fi
  sleep 2
done
echo "MySQL 기동 시간 초과 — docker compose logs mysql 확인"
exit 1
