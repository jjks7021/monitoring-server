package com.godoksa.monitoring.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.godoksa.monitoring.entity.ActivityLog;
import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.CrisisRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class AiRiskService {

    private final CrisisRepository crisisRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${ai.api.url:}")
    private String aiApiUrl;

    @Value("${ai.api.key:}")
    private String aiApiKey;

    @Value("${ai.model:gpt-4o-mini}")
    private String aiModel;

    public record AiResult(double probability, String summary) {
    }

    public AiResult assess(User user, List<ActivityLog> recentLogs, Double x, Double y, Double z,
            String locationTag, int currentDuration) {
        double ruleScore = computeRuleScore(user, currentDuration);
        if (aiApiKey == null || aiApiKey.isBlank()) {
            return new AiResult(ruleScore, "AI API 키 미설정 — 규칙 기반 확률만 사용합니다.");
        }
        try {
            AiResult aiResult = callOpenAi(user, recentLogs, x, y, z, locationTag, currentDuration);
            double finalScore = Math.max(ruleScore, aiResult.probability());
            String finalSummary = aiResult.summary();
            if (ruleScore > 0.6 && !finalSummary.contains("화장실")) {
                finalSummary = "[규칙 경고] " + finalSummary;
            }
            return new AiResult(finalScore, finalSummary);
        } catch (Exception e) {
            log.error("AI risk API failed for user {}: {} — {}", user.getLoginCode(), e.getClass().getSimpleName(),
                    e.getMessage(), e);
            return new AiResult(ruleScore, "ai api 크래딧 초과");
        }
    }

    private double computeRuleScore(User user, int currentDuration) {
        long crisisCount = crisisRepository.findByStatus(Crisis.CrisisStatus.CRISIS).stream()
                .filter(c -> c.getUser().getId().equals(user.getId()))
                .count();
        if (crisisCount >= 2)
            return 0.9;
        if (crisisCount == 1)
            return 0.7;
        Integer avg = user.getAvgToiletDuration() != null ? user.getAvgToiletDuration() : 20;
        if (currentDuration > avg * 3)
            return 0.65;
        return 0.15;
    }

    private AiResult callOpenAi(User user, List<ActivityLog> logs, Double x, Double y, Double z,
            String locationTag, int currentDuration) throws Exception {
        String logsJson = logs.stream().limit(20)
                .map(l -> String.format("{\"x\":%.3f,\"y\":%.3f,\"z\":%.3f,\"tag\":\"%s\"}",
                        l.getXCoord() != null ? l.getXCoord() : 0.0,
                        l.getYCoord() != null ? l.getYCoord() : 0.0,
                        l.getZCoord() != null ? l.getZCoord() : 0.0,
                        l.getLocationTag() != null ? l.getLocationTag() : "ROOM"))
                .collect(Collectors.joining(",", "[", "]"));

        String prompt = """
                당신은 시니어 고독사 예방을 위한 전문 분석 AI입니다. 주어진 데이터를 바탕으로 현재 위험도를 분석하세요.
                반드시 JSON 객체 하나만 응답하세요 (다른 텍스트 없음).

                [환자 정보] 이름: %s, 평소 화장실 체류 시간: %d분, 평소 활동성 수치: %.2f
                [현재 상황] 장소: %s, 현재 해당 장소 체류 시간: %d분, 현재 좌표: (%.3f, %.3f, %.3f)
                [최근 이동 로그] %s

                [응답 가이드라인]
                1. probability: 0.0에서 1.0 사이의 실수 (고독사 위험도가 높을수록 1.0에 가깝게 설정).
                   - 안전한 상태(위험도 낮음)인 경우: 0.0 ~ 0.3
                   - 주의가 필요한 상태(위험도 보통)인 경우: 0.4 ~ 0.6
                   - 위험한 상태(위험도 높음)인 경우: 0.7 ~ 1.0
                2. summary: 현재 상태를 친절하고 전문적으로 설명하는 한글 한 문장.

                *중요: probability 수치와 summary의 위험도 분석 내용은 반드시 서로 모순되지 않고 일치해야 합니다. 안전하다고 판단하여 낮은 위험도라고 요약했다면, probability도 반드시 0.3 이하여야 합니다.

                응답 형식: {"probability": 0.0, "summary": "요약 내용"}
                """.formatted(
                user.getName(),
                user.getAvgToiletDuration() != null ? user.getAvgToiletDuration() : 20,
                user.getAvgActivityRange() != null ? user.getAvgActivityRange() : 1.0,
                locationTag != null ? locationTag : "ROOM",
                currentDuration,
                x != null ? x : 0.0,
                y != null ? y : 0.0,
                z != null ? z : 0.0,
                logsJson);

        Map<String, Object> body = Map.of(
                "model", aiModel,
                "messages", List.of(Map.of("role", "user", "content", prompt)),
                "temperature", 0.3,
                "response_format", Map.of("type", "json_object"));

        log.info("=== AI REQUEST PROMPT ===\n{}", prompt);

        RestClient client = RestClient.builder().build();
        String response = client.post()
                .uri(aiApiUrl)
                .header("Authorization", "Bearer " + aiApiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(String.class);

        log.info("=== AI RESPONSE RAW ===\n{}", response);

        JsonNode root = objectMapper.readTree(response);
        String content = root.path("choices").path(0).path("message").path("content").asText();
        int start = content.indexOf('{');
        int end = content.lastIndexOf('}');
        if (start >= 0 && end > start) {
            content = content.substring(start, end + 1);
        }
        JsonNode parsed = objectMapper.readTree(content);
        double probability = parsed.path("probability").asDouble(0.1);
        String summary = parsed.path("summary").asText("AI 분석 완료");

        return new AiResult(probability, summary);
    }
}
