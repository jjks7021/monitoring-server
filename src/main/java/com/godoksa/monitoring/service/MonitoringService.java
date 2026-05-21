package com.godoksa.monitoring.service;

import com.godoksa.monitoring.entity.ActivityLog;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.ActivityLogRepository;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MonitoringService {

    private final ActivityLogRepository activityLogRepository;
    private final UserRepository userRepository;

    /**
     * 앱(Edge)에서 보내온 관절 좌표를 저장하고 분석하는 핵심 메서드
     */
    @Transactional
    public void analyzeMovement(String loginCode, Double x, Double y, String locationTag, int currentDuration) {
        // 1. 로그인 코드로 해당 어르신(User) 찾기
        User user = userRepository.findByLoginCode(loginCode)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사용자 코드입니다."));

        // 2. 받은 좌표 데이터 DB에 로그로 쌓기 (MoveNet 데이터 축적)
        ActivityLog log = ActivityLog.builder()
                .user(user)
                .xCoord(x)
                .yCoord(y)
                .locationTag(locationTag) // 'TOILET', 'ROOM' 등
                .build();
        activityLogRepository.save(log);

        // 3. 알고리즘 1: 화장실 체류 시간 분석 (Toilet Duration)
        if ("TOILET".equals(locationTag)) {
            checkToiletCrisis(user, currentDuration);
        }

        // 4. 알고리즘 2: 무기력 지수 분석 (Lethargy Index)
        checkLethargyCrisis(user);
    }

    /**
     * [알고리즘 1] 평소 화장실 체류 시간의 300%를 초과했는지 검사
     */
    private void checkToiletCrisis(User user, int currentDuration) {
        Integer avgToilet = user.getAvgToiletDuration(); // 유저 테이블에 저장된 평균 값 (기본 20분)
        
        if (currentDuration > avgToilet * 3) {
            System.out.println("🚨 [경고] " + user.getName() + " 어르신 낙상 및 심혈관 사고 의심! 평소 체류 시간의 300%를 초과했습니다.");
            // TODO: 추후 여기에 보호자에게 FCM 푸시 알림을 보내는 로직이 들어갑니다.
        }
    }

    /**
     * [알고리즘 2] 최근 3일간의 활동 반경(변화량)이 평소 대비 50% 이상 감소했는지 검사
     */
    private void checkLethargyCrisis(User user) {
        // DB에서 해당 유저의 최신 활동 로그들을 싹 긁어옴
        List<ActivityLog> logs = activityLogRepository.findByUserOrderByCreatedAtDesc(user);

        // 시연을 위해 로그가 어느 정도 쌓였을 때만 계산 진행
        if (logs.size() < 10) return;

        // TODO: logs 데이터를 가지고 최근 3일간의 x, y 좌표 변화량 변동 평균 계산 계산 알고리즘 구현
        // Double currentActivityRange = calculateRange(logs);
        // if (currentActivityRange < user.getAvgActivityRange() * 0.5) { ... }
    }
}