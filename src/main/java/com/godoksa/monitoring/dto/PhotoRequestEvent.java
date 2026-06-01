package com.godoksa.monitoring.dto;

public record PhotoRequestEvent(
        String type,
        String loginCode,
        String userName,
        String message) {
}
