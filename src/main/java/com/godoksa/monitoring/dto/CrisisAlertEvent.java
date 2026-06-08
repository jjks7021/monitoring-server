package com.godoksa.monitoring.dto;

// WebSocket /topic/crisis/{loginCode} 로 보내는 위기 알림 이벤트
public record CrisisAlertEvent(
        String type,
        String loginCode,
        String crisisType,
        String description,
        Long crisisId) {
}
