package com.godoksa.monitoring.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import java.time.LocalDateTime;

@Entity
@Table(name = "device") // SQL에서 명명한 테이블 이름과 통일
@Getter 
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String hardwareId; // 기기 고유 UUID (스마트폰 식별용)

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role; // PATIENT(어르신) 또는 WARD(보호자) - SQL과 통일

    private String fcmToken; // 알림 전송을 위한 토큰

    // --- 추가: 이 기기가 어떤 사용자의 것인지 연결 ---
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user; 
    // ------------------------------------------

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    public enum Role {
        PATIENT, WARD // SQL의 ENUM 설정과 동일하게 수정
    }
}