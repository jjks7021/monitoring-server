package com.godoksa.monitoring.service;

import com.godoksa.monitoring.entity.ActivityLog;
import com.godoksa.monitoring.entity.User;
import com.godoksa.monitoring.repository.CrisisRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

class AiRiskServiceTest {

    @Mock
    private CrisisRepository crisisRepository;

    @InjectMocks
    private AiRiskService aiRiskService;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        // Inject properties from application.properties manually for the test
        ReflectionTestUtils.setField(aiRiskService, "aiApiUrl",
                "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions");
        ReflectionTestUtils.setField(aiRiskService, "aiApiKey", "AIzaSyC5K_AI0u5A4NdbjWW_UMdanCx0N9K0bW4");
        ReflectionTestUtils.setField(aiRiskService, "aiModel", "gemini-2.5-flash");
    }

    @Test
    void testAssess() {
        User user = User.builder()
                .id(1L)
                .name("Test User")
                .avgToiletDuration(20)
                .avgActivityRange(1.5)
                .build();

        List<ActivityLog> logs = new ArrayList<>();
        logs.add(ActivityLog.builder()
                .xCoord(0.123)
                .yCoord(0.456)
                .zCoord(0.789)
                .locationTag("ROOM")
                .build());

        when(crisisRepository.findByStatus(any())).thenReturn(new ArrayList<>());

        AiRiskService.AiResult result = aiRiskService.assess(user, logs, 0.1, 0.2, 0.3, "TOILET", 25);

        System.out.println("AI Probability: " + result.probability());
        System.out.println("AI Summary: " + result.summary());

        assertNotNull(result);
        assertNotNull(result.summary());
    }
}
