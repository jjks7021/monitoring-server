package com.godoksa.monitoring.dto;

import com.godoksa.monitoring.entity.Crisis;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class CrisisResponse {
    private final Long id;
    private final String loginCode;
    private final String userName;
    private final String crisisType;
    private final String status;
    private final String description;
    private final LocalDateTime createdAt;

    public static CrisisResponse from(Crisis crisis) {
        return CrisisResponse.builder()
                .id(crisis.getId())
                .loginCode(crisis.getUser().getLoginCode())
                .userName(crisis.getUser().getName())
                .crisisType(crisis.getCrisisType())
                .status(crisis.getStatus().name())
                .description(crisis.getDescription())
                .createdAt(crisis.getCreatedAt())
                .build();
    }
}
