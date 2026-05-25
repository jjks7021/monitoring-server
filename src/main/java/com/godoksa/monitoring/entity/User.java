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
@Table(name = "users") // "user"는 H2 예약어이므로 "users"로 변경
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String loginCode; // 6자리 로그인 코드

    @Column(nullable = false)
    private String name; // 시연용 이름

    @Column(nullable = false)
    private String role; // "WARD"(보호자) 또는 "PATIENT"(환자)

    // --- 고독사 예방 분석을 위한 기준 데이터 필드 추가 ---

    @Builder.Default
    private Integer avgToiletDuration = 20; // 평소 화장실 체류 평균 시간 (단위: 분)

    @Builder.Default
    private Double avgActivityRange = 0.0; // 최근 3일간 평균 활동 반경 ($x, y$ 변화량)

    // ----------------------------------------------

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt; // 계정 생성 시간
}