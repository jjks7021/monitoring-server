package com.godoksa.monitoring.repository;

import com.godoksa.monitoring.entity.ActivityLog;
import com.godoksa.monitoring.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ActivityLogRepository extends JpaRepository<ActivityLog, Long> {
    
    // 특정 유저의 활동 기록을 최신순으로 가져오는 기능 (나중에 무기력 지수 계산할 때 씀)
    List<ActivityLog> findByUserOrderByCreatedAtDesc(User user);
}