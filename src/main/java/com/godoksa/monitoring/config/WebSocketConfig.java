package com.godoksa.monitoring.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // 메시지 브로커가 처리할 프리픽스 설정
        config.enableSimpleBroker("/topic");
        // 메시지 핸들러로 전달될 프리픽스 설정
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // 웹 브라우저용 (SockJS)
        registry.addEndpoint("/ws-monitoring")
                .setAllowedOriginPatterns("*")
                .withSockJS();
        // Flutter/네이티브 클라이언트용 (순수 WebSocket)
        registry.addEndpoint("/ws-native")
                .setAllowedOriginPatterns("*");
    }
}
