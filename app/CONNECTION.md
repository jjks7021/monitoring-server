# 백엔드 연동 가이드

## 테스트 계정 (서버 dev 프로필 기동 시 자동 생성)
| 역할 | loginCode | 이름 |
|------|-----------|------|
| 피보호자 | 523891 | 김영숙 |
| 보호자 | 111111 | 김보호 |

## 1. 백엔드 실행

### MySQL 사용 (팀 DB)
```bash
cd ..   # monitoring-server 루트
./gradlew bootRun
```

### 로컬 빠른 테스트 (H2, MySQL 없이)
```bash
cd ..
SPRING_PROFILES_ACTIVE=dev ./gradlew bootRun
```

## 2. Flutter 앱 실행

```bash
cd app
flutter pub get
# Android 에뮬레이터
flutter run
# 실제 폰 (Mac IP 확인: ipconfig getifaddr en0)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080
```

## 3. 앱에서 테스트 순서

### 피보호자
1. 피보호자용 선택 → 시작
2. **「보호자 연결 수락 시뮬레이션」** 탭 → 서버 로그인+기기등록 (코드 523891)
3. 카메라 탭에서 x/y/z 좌표·고독사 확률 확인

### 보호자
1. 보호자용 선택 → 코드 **523891** 입력 → 연결하기
2. (추후) 알림 탭에서 `/api/crisis/active` 연동 예정

## API 주소 설정
`lib/config/api_config.dart` — 기본값 `http://10.0.2.2:8080` (Android 에뮬레이터)
