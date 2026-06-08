package com.godoksa.monitoring.service;

import com.godoksa.monitoring.dto.CoordinateResponse;
import com.godoksa.monitoring.entity.ActivityLog;
import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.entity.RiskAssessment;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.ActivityLogRepository;
import com.godoksa.monitoring.repository.CrisisRepository;
import com.godoksa.monitoring.repository.RiskAssessmentRepository;
import com.godoksa.monitoring.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
        private final RiskAssessmentRepository riskAssessmentRepository;
        private final AiRiskService aiRiskService;
        private final CrisisAlertService crisisAlertService;
        private final SimpMessagingTemplate messagingTemplate;

        @Transactional
        public CoordinateResponse analyzeMovement(String loginCode,
                        Double x, Double y, Double z, String locationTag, int currentDuration) {
                User user = userRepository.findByLoginCode(loginCode)
                                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사용자 코드입니다."));

                ActivityLog log = ActivityLog.builder()
                                .user(user)
                                .xCoord(x)
                                .yCoord(y)
                                .zCoord(z)
                                .locationTag(locationTag)
                                .build();
                activityLogRepository.save(log);

                if ("TOILET".equals(locationTag)) {
                        checkToiletCrisis(user, currentDuration);
                }
                if (x != null && y != null) {
                        checkLethargyCrisis(user);
                }

                List<ActivityLog> recentLogs = activityLogRepository.findByUserOrderByCreatedAtDesc(user);
                AiRiskService.AiResult aiResult = aiRiskService.assess(user, recentLogs, x, y, z, locationTag,
                                currentDuration);

                crisisAlertService.raiseAiHighRiskIfNeeded(user, aiResult.probability(), aiResult.summary());

                List<String> activeCrises = crisisRepository.findByStatus(Crisis.CrisisStatus.CRISIS).stream()
                                .filter(c -> c.getUser().getId().equals(user.getId()))
                                .map(Crisis::getCrisisType)
                                .toList();

                String ruleAlerts = String.join(",", activeCrises);
                riskAssessmentRepository.save(RiskAssessment.builder()
                                .user(user)
                                .probability(aiResult.probability())
                                .aiSummary(aiResult.summary())
                                .ruleAlerts(ruleAlerts.isEmpty() ? null : ruleAlerts)
                                .build());

                CoordinateResponse response = CoordinateResponse.builder()
                                .message("데이터 수신 및 분석 완료")
                                .logId(log.getId())
                                .solitaryDeathProbability(aiResult.probability())
                                .aiSummary(aiResult.summary())
                                .activeCrises(activeCrises)
                                .build();

                // 실시간으로 보호자 앱에 분석 결과 전송
                messagingTemplate.convertAndSend("/topic/risk/" + loginCode, response);

                return response;
        }

        private void checkToiletCrisis(User user, int currentDuration) {
                int avgToilet = user.getAvgToiletDuration() != null ? user.getAvgToiletDuration() : 20;
                if (currentDuration > avgToilet * 3) {
                        boolean exists = crisisRepository.findByUserAndStatus(user, Crisis.CrisisStatus.CRISIS)
                                        .map(c -> "TOILET_OVERFLOW".equals(c.getCrisisType()))
                                        .orElse(false);
                        if (!exists) {
                                crisisRepository.save(Crisis.builder()
                                                .user(user)
                                                .crisisType("TOILET_OVERFLOW")
                                                .status(Crisis.CrisisStatus.CRISIS)
                                                .description("평소 체류 시간의 300% 초과 (현재: " + currentDuration + "분)")
                                                .createdAt(LocalDateTime.now())
                                                .build());
                        }
                }
        }

        private void checkLethargyCrisis(User user) {
                List<ActivityLog> allLogs = activityLogRepository.findByUserOrderByCreatedAtDesc(user).stream()
                                .filter(l -> l.getXCoord() != null && l.getYCoord() != null)
                                .limit(10)
                                .toList();
                if (allLogs.size() < 10)
                        return;

                double currentRange = calculateCurrentRange(allLogs);
                double normalRange = (user.getAvgActivityRange() != null && user.getAvgActivityRange() > 0)
                                ? user.getAvgActivityRange()
                                : 1.0;

                if (currentRange < normalRange * 0.5) {
                        boolean exists = crisisRepository.findByUserAndStatus(user, Crisis.CrisisStatus.CRISIS)
                                        .map(c -> "LETHARGY".equals(c.getCrisisType()))
                                        .orElse(false);
                        if (!exists) {
                                crisisRepository.save(Crisis.builder()
                                                .user(user)
                                                .crisisType("LETHARGY")
                                                .status(Crisis.CrisisStatus.CRISIS)
                                                .description("3D 활동 반경 급감 (현재: " + String.format("%.2f", currentRange)
                                                                + ")")
                                                .createdAt(LocalDateTime.now())
                                                .build());
                        }
                }
        }

        private double calculateCurrentRange(List<ActivityLog> logs) {
                double sumX = 0, sumY = 0, sumZ = 0;
                for (int i = 0; i < 10; i++) {
                        sumX += logs.get(i).getXCoord();
                        sumY += logs.get(i).getYCoord();
                        sumZ += logs.get(i).getZCoord() != null ? logs.get(i).getZCoord() : 0.0;
                }
                double avgX = sumX / 10, avgY = sumY / 10, avgZ = sumZ / 10;

                double varianceSum = 0;
                for (int i = 0; i < 10; i++) {
                        double dx = logs.get(i).getXCoord() - avgX;
                        double dy = logs.get(i).getYCoord() - avgY;
                        double dz = (logs.get(i).getZCoord() != null ? logs.get(i).getZCoord() : 0.0) - avgZ;
                        varianceSum += Math.sqrt(dx * dx + dy * dy + dz * dz);
                }
                return varianceSum / 10;
        }

        public Map<String, Long> getLocationStatistics(String loginCode) {
                User user = userRepository.findByLoginCode(loginCode)
                                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사용자 코드입니다."));
                return activityLogRepository.findByUserOrderByCreatedAtDesc(user).stream()
                                .filter(log -> log.getLocationTag() != null)
                                .collect(Collectors.groupingBy(ActivityLog::getLocationTag, Collectors.counting()));
        }
}
