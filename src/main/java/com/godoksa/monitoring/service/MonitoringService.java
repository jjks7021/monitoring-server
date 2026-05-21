package com.godoksa.monitoring.service;

import com.godoksa.monitoring.entity.ActivityLog;
import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.ActivityLogRepository;
import com.godoksa.monitoring.repository.CrisisRepository;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.PrintStream;
import java.io.UnsupportedEncodingException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MonitoringService {

    private final ActivityLogRepository activityLogRepository;
    private final UserRepository userRepository;
    private final CrisisRepository crisisRepository;

    /**
     * 윈도우 파워쉘/CMD 한글 깨짐 방지용 안전 출력 메서드
     */
    private void safePrintln(String message) {
        try {
            // 현재 시스템의 stdout 인코딩 설정을 따르되, 기본값이 깨질 확률이 높은 윈도우 환경(sun.stdout.encoding 미지정 등)을 고려
            String encoding = System.getProperty("sun.stdout.encoding");
            if (encoding == null) {
                encoding = System.getProperty("file.encoding", "UTF-8");
            }
            
            // 시스템 인코딩 바이트 스트림으로 변환 후 강제 출력
            byte[] bytes = message.getBytes(encoding);
            System.out.write(bytes);
            System.out.println();
        } catch (Exception e) {
            // 예외 발생 시 표준 출력으로 우회
            System.out.println(message);
        }
    }

    @Transactional
    public void analyzeMovement(String loginCode, Double x, Double y, String locationTag, int currentDuration) {
        User user = userRepository.findByLoginCode(loginCode)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사용자 코드입니다."));

        ActivityLog log = ActivityLog.builder()
                .user(user)
                .xCoord(x)
                .yCoord(y)
                .locationTag(locationTag)
                .build();
        activityLogRepository.save(log);

        if ("TOILET".equals(locationTag)) {
            checkToiletCrisis(user, currentDuration);
        }

        // 완전히 새로 고친 무기력 지수 알고리즘 호출
        checkLethargyCrisis(user);
    }

    private void checkToiletCrisis(User user, int currentDuration) {
        Integer avgToilet = user.getAvgToiletDuration();
        if (avgToilet == null) avgToilet = 20;
        
        if (currentDuration > avgToilet * 3) {
            safePrintln("🚨 [위험 경보] " + user.getName() + " 어르신 낙상 의심! (현재: " + currentDuration + "분)");
            
            boolean isAlreadyExist = crisisRepository.findByUserAndStatus(user, Crisis.CrisisStatus.CRISIS)
                    .stream()
                    .anyMatch(c -> "TOILET_OVERFLOW".equals(c.getCrisisType()));

            if (!isAlreadyExist) {
                Crisis crisis = Crisis.builder()
                        .user(user)
                        .crisisType("TOILET_OVERFLOW")
                        .status(Crisis.CrisisStatus.CRISIS)
                        .description("평소 체류 시간의 300%를 초과하여 화장실에 머무는 중입니다. (현재: " + currentDuration + "분)")
                        .createdAt(LocalDateTime.now())
                        .build();
                crisisRepository.save(crisis);
                safePrintln("💾 DB에 화장실 낙상 의심 실시간 위험 상황(Crisis) 등록 완료!");
            }
        }
    }

    /**
     * [구조 개선된 알고리즘 2] 데이터 찌꺼기에 영향을 받지 않는 실시간 무기력 지수 분석
     */
    private void checkLethargyCrisis(User user) {
        // 전체 로그를 가져오는 대신, 최근 10개만 깔끔하게 끊어서 가져옴
        List<ActivityLog> allLogs = activityLogRepository.findByUserOrderByCreatedAtDesc(user);
        if (allLogs.size() < 10) return;

        // 1. [현재 반경 계산] 최신 10개 로그의 중심점(평균) 구하기
        double sumX = 0, sumY = 0;
        for (int i = 0; i < 10; i++) {
            sumX += allLogs.get(i).getXCoord();
            sumY += allLogs.get(i).getYCoord();
        }
        double avgX = sumX / 10;
        double avgY = sumY / 10;

        // 최신 10개의 변동 폭(현재 활동 반경) 계산
        double varianceSum = 0;
        for (int i = 0; i < 10; i++) {
            double diffX = allLogs.get(i).getXCoord() - avgX;
            double diffY = allLogs.get(i).getYCoord() - avgY;
            varianceSum += Math.sqrt((diffX * diffX) + (diffY * diffY));
        }
        double currentActivityRange = varianceSum / 10;

        // 2. [기준값 설정 부 버그 수정] 
        // DB 유저 테이블에 세팅된 활동 반경이 없거나 0 이하인 비정상 데이터일 경우, 기본 반경 임계치를 1.0으로 강제 방어
        double normalRange = (user.getAvgActivityRange() != null && user.getAvgActivityRange() > 0) 
                             ? user.getAvgActivityRange() : 1.0;

        // 3. [비교 연산 및 예외 처리]
        // 현재 반경이 평소의 50% 미만으로 떨어졌고, '실제로 거의 안 움직이는 상태(예: 반경 0.1 이하)'가 되었을 때만 무기력증으로 최종 판정
        if (currentActivityRange < normalRange * 0.5) {
            
            safePrintln("🚨 [위험 경보] " + user.getName() + " 어르신 무기력 지수 초과! 최근 활동 반경이 평소 대비 50% 이상 감소했습니다.");
            safePrintln("   (기준 반경: " + String.format("%.2f", normalRange) + " / 현재 반경: " + String.format("%.2f", currentActivityRange) + ")");
            
            boolean isAlreadyExist = crisisRepository.findByUserAndStatus(user, Crisis.CrisisStatus.CRISIS)
                    .stream()
                    .anyMatch(c -> "LETHARGY".equals(c.getCrisisType()));

            if (!isAlreadyExist) {
                Crisis crisis = Crisis.builder()
                        .user(user)
                        .crisisType("LETHARGY")
                        .status(Crisis.CrisisStatus.CRISIS)
                        .description("최근 활동 반경이 평소 대비 50% 이상 급감하여 무기력증이 의심됩니다. (현재 반경: " + String.format("%.2f", currentActivityRange) + ")")
                        .createdAt(LocalDateTime.now())
                        .build();
                crisisRepository.save(crisis);
                safePrintln("💾 DB에 무기력 지수 초과 실시간 위험 상황(Crisis) 등록 완료!");
            }
        }
    }

    public Map<String, Long> getLocationStatistics(String loginCode) {
        User user = userRepository.findByLoginCode(loginCode)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사용자 코드입니다."));

        List<ActivityLog> logs = activityLogRepository.findByUserOrderByCreatedAtDesc(user);

        return logs.stream()
                .filter(log -> log.getLocationTag() != null)
                .collect(Collectors.groupingBy(
                        ActivityLog::getLocationTag,
                        Collectors.counting()
                ));
    }
}