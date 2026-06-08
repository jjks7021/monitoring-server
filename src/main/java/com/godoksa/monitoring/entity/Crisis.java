package com.godoksa.monitoring.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Builder
public class Crisis {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    private String crisisType; // 위기 유형 (TOILET_OVERFLOW, LETHARGY, AI_HIGH_RISK 등)

    @Enumerated(EnumType.STRING)
    private CrisisStatus status; // CRISIS(위험 중), RESOLVED(해결됨)

    private String description;

    private LocalDateTime createdAt;
    private LocalDateTime resolvedAt;

    public enum CrisisStatus {
        CRISIS, RESOLVED
    }

    // 위험 상황 해결 처리
    public void resolveCrisis() {
        this.status = CrisisStatus.RESOLVED;
        this.resolvedAt = LocalDateTime.now();
    }
}