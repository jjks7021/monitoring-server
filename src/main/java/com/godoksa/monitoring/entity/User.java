package com.godoksa.monitoring.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import org.hibernate.annotations.CreationTimestamp;

@Entity
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String loginCode; // 6자리 연결 코드

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String role; // "PATIENT"(피보호자) 또는 "GUARDIAN"(보호자)

    @Builder.Default
    private Integer avgToiletDuration = 20; // 평소 화장실 체류 시간 (분)

    @Builder.Default
    private Double avgActivityRange = 0.0; // 최근 평균 활동 반경

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;
}