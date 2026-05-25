# Silver Care Monitoring

Spring Boot 백엔드 + Flutter 앱 (카메라 포즈 x/y/z → 서버 저장 → AI 고독사 확률)

## 백엔드 실행

```bash
./gradlew bootRun
```

- MySQL `godoksa_db` 필요 (application.properties 참고)
- AI 분석: 환경변수 `AI_API_KEY` 설정 시 OpenAI 호출, 미설정 시 규칙 기반만

## API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/users/login` | `{"loginCode":"123456"}` |
| POST | `/api/devices/register` | `hardwareId`, `loginCode` |
| POST | `/api/devices/coordinates` | `x`, `y`, `z`, `locationTag`, `currentDuration` |
| GET | `/api/crisis/active` | 활성 위험 목록 |

## Flutter 앱

```bash
cd flutter_app
flutter pub get
flutter run
```

- Android 에뮬레이터 기본 API: `http://10.0.2.2:8080`
- 실기기: `flutter run --dart-define=API_BASE_URL=http://<PC_IP>:8080`
