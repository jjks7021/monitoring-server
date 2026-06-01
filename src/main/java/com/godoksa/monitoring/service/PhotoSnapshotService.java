package com.godoksa.monitoring.service;

import com.godoksa.monitoring.dto.PhotoReadyEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 긴급 사진은 DB·디스크에 저장하지 않고 메모리에만 잠시 보관.
 * 보호자가 1회 조회하면 즉시 삭제(consume).
 */
@Service
@RequiredArgsConstructor
public class PhotoSnapshotService {

    private static final long TTL_MS = 60_000;

    private final SimpMessagingTemplate messagingTemplate;

    private record Entry(byte[] data, String contentType, long expiresAt) {
    }

    private final ConcurrentHashMap<String, Entry> cache = new ConcurrentHashMap<>();

    public void storeAndNotify(String loginCode, byte[] imageBytes, String contentType) {
        cache.put(loginCode, new Entry(imageBytes, contentType, System.currentTimeMillis() + TTL_MS));
        messagingTemplate.convertAndSend(
                "/topic/photo-ready/" + loginCode,
                new PhotoReadyEvent("PHOTO_READY", loginCode));
    }

  /** 보호자 1회 열람 후 메모리에서 삭제 */
    public Optional<CachedPhoto> consume(String loginCode) {
        Entry entry = cache.remove(loginCode);
        if (entry == null) {
            return Optional.empty();
        }
        if (System.currentTimeMillis() > entry.expiresAt()) {
            return Optional.empty();
        }
        return Optional.of(new CachedPhoto(entry.data(), entry.contentType()));
    }

    public record CachedPhoto(byte[] data, String contentType) {
    }
}
