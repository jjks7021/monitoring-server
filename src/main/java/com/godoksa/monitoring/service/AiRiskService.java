package com.godoksa.monitoring.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.godoksa.monitoring.entity.ActivityLog;
import com.godoksa.monitoring.entity.Crisis;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.CrisisRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
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
            // 429 에러나 일시적 장애 시 사용자를 위한 대체 분석 제공
            String fallbackSummary = generateFallbackSummary(locationTag, currentDuration, x, y);
            return new AiResult(ruleScore, fallbackSummary);
        }
    }

    private String generateFallbackSummary(String locationTag, int duration, Double x, Double y) {
        String place = locationTag.equals("TOILET") ? "화장실" : "거실";
        if (locationTag.equals("TOILET") && duration > 15) {
            return String.format("%s에 %d분째 체류 중입니다. 평소보다 시간이 길어져 주의가 필요합니다.", place, duration);
        }
        return String.format("%s에서 규칙적인 활동이 감지되고 있습니다. (상태 양호)", place);
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
                        l.getXCoord(), l.getYCoord(),
                        l.getZCoord() != null ? l.getZCoord() : 0,
                        l.getLocationTag()))
                .collect(Collectors.joining(",", "[", "]"));

        String prompt = """
                당신은 시니어 고독사 예방을 위한 전문 분석 AI입니다. 주어진 데이터를 바탕으로 현재 위험도를 분석하세요.
                반드시 JSON 형식으로만 응답하세요.

                [환자 정보] 이름: %s, 평소 화장실 체류 시간: %d분, 평소 활동성 수치: %.2f
                [현재 상황] 장소: %s, 현재 해당 장소 체류 시간: %d분, 현재 좌표: (%.3f, %.3f, %.3f)
                [최근 이동 로그] %s

                [응답 가이드라인]
                1. probability: 0.0에서 1.0 사이의 실수 (위험할수록 1.0에 가깝게)
                2. summary: 현재 상태를 친절하고 전문적으로 설명하는 한글 한 문장 (예: "거실에서 활발한 움직임이 감지되어 매우 안전한 상태입니다.")

                응답 형식: {"probability": 0.0, "summary": "요약 내용"}
                """.formatted(user.getName(), user.getAvgToiletDuration(), user.getAvgActivityRange(),
                locationTag, currentDuration, x, y, z, logsJson);

        Map<String, Object> body = Map.of(
                "model", aiModel,
                "messages", List.of(Map.of("role", "user", "content", prompt)),
                "temperature", 0.7 // 창의적인 요약을 위해 약간 높임
        );

        RestClient client = RestClient.builder().build();
        String response = client.post()
                .uri(aiApiUrl)
                .header("Authorization", "Bearer " + aiApiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(String.class);

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
