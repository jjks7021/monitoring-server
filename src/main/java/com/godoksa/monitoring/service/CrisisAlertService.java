package com.godoksa.monitoring.service;

import com.godoksa.monitoring.dto.CrisisAlertEvent;
import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.CrisisRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * 보호자 앱 실시간 위험 알림 — DB Crisis + WebSocket /topic/crisis/{loginCode}
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CrisisAlertService {

    public static final String AI_HIGH_RISK = "AI_HIGH_RISK";
    public static final String TEST_MANUAL = "TEST_MANUAL";

    private final CrisisRepository crisisRepository;
    private final SimpMessagingTemplate messagingTemplate;

    @Value("${monitoring.ai.crisis-threshold:0.6}")
    private double aiCrisisThreshold;

    /**
     * AI 고독사 확률이 임계값 이상이면 Crisis 생성 후 보호자에게 알림 (최초 1회, 동일 유형 활성 시 재알림 없음)
     */
    @Transactional
    public void raiseAiHighRiskIfNeeded(User user, double probability, String aiSummary) {
        if (probability < aiCrisisThreshold) {
            return;
        }
        String loginCode = user.getLoginCode();
        boolean alreadyActive = crisisRepository
                .findByUser_LoginCodeAndStatus(loginCode, Crisis.CrisisStatus.CRISIS)
                .stream()
                .anyMatch(c -> AI_HIGH_RISK.equals(c.getCrisisType()));
        if (alreadyActive) {
            return;
        }

        String desc = String.format(
                "AI 고독사 위험도 %.0f%% (임계 %.0f%%). %s",
                probability * 100,
                aiCrisisThreshold * 100,
                aiSummary != null && !aiSummary.isBlank() ? aiSummary : "상세 분석 없음");

        Crisis crisis = crisisRepository.save(Crisis.builder()
                .user(user)
                .crisisType(AI_HIGH_RISK)
                .status(Crisis.CrisisStatus.CRISIS)
                .description(desc)
                .createdAt(LocalDateTime.now())
                .build());

        publish(crisis, loginCode);
        log.info("AI_HIGH_RISK crisis raised for loginCode={} probability={}", loginCode, probability);
    }

    @Transactional
    public Crisis raiseManualTestCrisis(User user) {
        String loginCode = user.getLoginCode();
        var existing = crisisRepository
                .findByUser_LoginCodeAndStatus(loginCode, Crisis.CrisisStatus.CRISIS)
                .stream()
                .filter(c -> TEST_MANUAL.equals(c.getCrisisType()))
                .findFirst();
        if (existing.isPresent()) {
            Crisis crisis = existing.get();
            publish(crisis, loginCode);
            return crisis;
        }
        Crisis crisis = crisisRepository.save(Crisis.builder()
                .user(user)
                .crisisType(TEST_MANUAL)
                .status(Crisis.CrisisStatus.CRISIS)
                .description("피보호자 테스트 버튼 — 알림 경로만 확인용 (AI 위험도와 무관)")
                .createdAt(LocalDateTime.now())
                .build());
        publish(crisis, loginCode);
        return crisis;
    }

    public double getAiCrisisThreshold() {
        return aiCrisisThreshold;
    }

    private void publish(Crisis crisis, String loginCode) {
        messagingTemplate.convertAndSend(
                "/topic/crisis/" + loginCode,
                new CrisisAlertEvent(
                        "CRISIS_ALERT",
                        loginCode,
                        crisis.getCrisisType(),
                        crisis.getDescription(),
                        crisis.getId()));
    }
}
