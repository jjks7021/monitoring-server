package com.godoksa.monitoring.dto;

import lombok.Builder;
import lombok.Getter;
import java.util.List;

@Getter
@Builder
public class CoordinateResponse {
    private String message;
    private Long logId;
    private double solitaryDeathProbability;
    private String aiSummary;
    private List<String> activeCrises;
}
