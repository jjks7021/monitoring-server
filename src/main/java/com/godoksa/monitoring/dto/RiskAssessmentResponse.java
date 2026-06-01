package com.godoksa.monitoring.dto;

import com.godoksa.monitoring.entity.RiskAssessment;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class RiskAssessmentResponse {
    private final double probability;
    private final String aiSummary;
    private final String ruleAlerts;
    private final LocalDateTime createdAt;

    public static RiskAssessmentResponse from(RiskAssessment assessment) {
        return RiskAssessmentResponse.builder()
                .probability(assessment.getProbability() != null ? assessment.getProbability() : 0.0)
                .aiSummary(assessment.getAiSummary())
                .ruleAlerts(assessment.getRuleAlerts())
                .createdAt(assessment.getCreatedAt())
                .build();
    }
}
