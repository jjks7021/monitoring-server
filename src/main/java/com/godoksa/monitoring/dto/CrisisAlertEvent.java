package com.godoksa.monitoring.dto;

/**
 * WebSocket: /topic/crisis/{loginCode} — 보호자 앱 실시간 알림용
 */
public record CrisisAlertEvent(
        String type,
        String loginCode,
        String crisisType,
        String description,
        Long crisisId) {
}
