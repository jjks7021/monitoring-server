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
        config.enableSimpleBroker("/topic");
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // 웹 브라우저용 엔드포인트
        registry.addEndpoint("/ws-monitoring")
                .setAllowedOriginPatterns("*")
                .withSockJS();
        // Flutter 앱용 순수 WebSocket 엔드포인트
        registry.addEndpoint("/ws-native")
                .setAllowedOriginPatterns("*");
    }
}
