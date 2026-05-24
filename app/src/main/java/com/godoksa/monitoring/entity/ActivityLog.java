package com.godoksa.monitoring.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import java.time.LocalDateTime;

@Entity
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ActivityLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user; // 누구의 활동 기록인지

    private Double xCoord; // MoveNet x 좌표
    private Double yCoord; // MoveNet y 좌표

    private String locationTag; // 'TOILET', 'ROOM' 등

    @CreationTimestamp
    private LocalDateTime createdAt; // 좌표가 찍힌 시간
}