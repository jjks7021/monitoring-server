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

    private String crisisType; // "TOILET_OVERFLOW" 또는 "LETHARGY"

    @Enumerated(EnumType.STRING)
    private CrisisStatus status; // CRISIS(위험), RESOLVED(해결됨)

    private String description; // 상세 내용 설명

    private LocalDateTime createdAt;
    private LocalDateTime resolvedAt;

    public enum CrisisStatus {
        CRISIS, RESOLVED
    }

    // 위험 상황 해결 시 상태 변경하는 메서드
    public void resolveCrisis() {
        this.status = CrisisStatus.RESOLVED;
        this.resolvedAt = LocalDateTime.now();
    }
}