package com.godoksa.monitoring.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class CoordinateRequest {
    private String loginCode;
    private String hardwareId;
    private Double x;
    private Double y;
    private Double z;
    private String locationTag;
    private Integer currentDuration;
}
