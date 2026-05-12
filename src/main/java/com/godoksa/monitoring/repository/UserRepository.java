package com.godoksa.monitoring.repository;

import com.godoksa.monitoring.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    // 6자리 코드로 유저를 찾는 기능을 추가합니다.
    Optional<User> findByLoginCode(String loginCode);
}