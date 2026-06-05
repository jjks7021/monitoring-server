# 앱 ↔ 서버 연결 방법

## 로컬 개발 (맥북 1대)

1. `docker compose up -d` (프로젝트 루트)
2. `./gradlew bootRun` (루트 `MonitoringServerApplication`)
3. `cd app && flutter run -d macos` — 기본 API `http://127.0.0.1:8080`

피보호자·보호자를 **둘 다 같은 맥**에서 테스트할 때도 Spring은 **한 번만** 실행하세요.

### macOS에서 카메라가 안 뜰 때

**IntelliJ에 카메라 권한을 줘도 효과 없습니다.** 카메라를 쓰는 프로세스는 IDE가 아니라 Flutter가 띄운 **`monitoring_app`** 입니다.

1. 공식 `camera` 패키지는 **macOS 미지원** → 이 프로젝트는 **`camera_desktop`** 을 함께 씁니다. `pubspec.yaml` 변경 후 **완전 재빌드** (`flutter run -d macos`, hot reload만으로는 플러그인 미등록).
2. **시스템 설정 → 개인정보 보호 및 보안 → 카메라**에서 **`monitoring_app`**(또는 `monitoring_app.app`)을 켭니다. 목록에 없으면 앱을 한 번 실행한 뒤 다시 확인.
3. **ML Kit 포즈**는 Android/iOS만 지원합니다. macOS에서는 카메라 미리보기·긴급 사진은 가능하고, **좌표는 시뮬레이션**으로 서버에 전송됩니다.

## 연결 코드 (6자리)

- **피보호자**: 서버에서 코드 발급 → 보호자에게 전달
- **보호자**: 동일 6자리 입력

## API

| 역할 | 엔드포인트 |
|------|-----------|
| 피보호자 | `POST /api/users/patient/connect` |
| 보호자 | `POST /api/users/guardian/connect` |

## 플랫폼별 API 주소 (기본값)

| 환경 | API |
|------|-----|
| macOS / iOS / Windows | `http://127.0.0.1:8080` |
| Android 에뮬레이터 | `http://10.0.2.2:8080` |
| Android 실기기 / 원격 팀원 | `--dart-define=API_BASE_URL=http://<호스트IP>:8080` 또는 ngrok HTTPS |

## 팀원 원격 접속 (나중에)

호스트만 Spring + MySQL 실행. 팀원은 **ngrok HTTP(8080)** 로 백엔드에 붙는 것을 권장합니다.

```bash
# 호스트
ngrok http 8080

# 팀원 Flutter (Spring 실행 X)
flutter run -d macos --dart-define=API_BASE_URL=https://xxxx.ngrok-free.app
```

MySQL만 `ngrok tcp 3306`으로 공유하면 DB CRUD만 맞고, **실시간 알림(WebSocket)·긴급 사진**은 동작하지 않을 수 있습니다.

## 백엔드 위치

**루트** `src/main/java/.../MonitoringServerApplication` — `app/src/main/java` 구버전 사용 금지
