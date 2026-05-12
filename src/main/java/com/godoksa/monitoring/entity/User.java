package com.godoksa.monitoring.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true)
    private String loginCode; // 6자리 로그인 코드

    private String role; // "WARD"(보호자) 또는 "PATIENT"(환자)
    private String name; // 시연용 이름
}