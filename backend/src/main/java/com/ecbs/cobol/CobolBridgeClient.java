package com.ecbs.cobol;

import java.time.Duration;
import java.util.Map;
import java.util.function.Supplier;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.ClientHttpRequestFactorySettings;
import org.springframework.boot.web.client.ClientHttpRequestFactories;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

/**
 * Client for the COBOL bridge running inside the cobol-runtime container.
 * Every business operation that must go through the COBOL layer is
 * dispatched here, mimicking how a middleware would route requests to
 * CICS transactions.
 *
 * <p>Fase 15: the HTTP call has bounded connect/read timeouts and retries
 * transient failures (connection refused / read timeout / 5xx) a few times
 * with a fixed backoff, so a momentary bridge hiccup does not surface as a
 * request error.
 */
@Component
public class CobolBridgeClient {

    private static final Logger log = LoggerFactory.getLogger(CobolBridgeClient.class);

    private final RestClient restClient;
    private final int maxRetries;
    private final long retryBackoffMs;

    public CobolBridgeClient(
            @Value("${ecbs.cobol-bridge.url}") String bridgeUrl,
            @Value("${ecbs.cobol-bridge.connect-timeout-ms:2000}") long connectTimeoutMs,
            @Value("${ecbs.cobol-bridge.read-timeout-ms:65000}") long readTimeoutMs,
            @Value("${ecbs.cobol-bridge.max-retries:2}") int maxRetries,
            @Value("${ecbs.cobol-bridge.retry-backoff-ms:200}") long retryBackoffMs) {
        ClientHttpRequestFactorySettings settings = ClientHttpRequestFactorySettings.DEFAULTS
                .withConnectTimeout(Duration.ofMillis(connectTimeoutMs))
                .withReadTimeout(Duration.ofMillis(readTimeoutMs));
        this.restClient = RestClient.builder()
                .baseUrl(bridgeUrl)
                .requestFactory(ClientHttpRequestFactories.get(settings))
                .build();
        this.maxRetries = Math.max(0, maxRetries);
        this.retryBackoffMs = Math.max(0, retryBackoffMs);
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> health() {
        return withRetry("health", () -> restClient.get()
                .uri("/health")
                .retrieve()
                .body(Map.class));
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> runProgram(String programName, Map<String, Object> payload) {
        return withRetry("run/" + programName, () -> restClient.post()
                .uri("/run/{program}", programName)
                .body(payload)
                .retrieve()
                .body(Map.class));
    }

    /**
     * Runs {@code call}, retrying transient failures (I/O errors, timeouts
     * and 5xx responses) up to {@code maxRetries} times with a fixed backoff.
     * Non-transient errors (e.g. 4xx) propagate immediately.
     */
    private <T> T withRetry(String op, Supplier<T> call) {
        int attempt = 0;
        while (true) {
            try {
                return call.get();
            } catch (ResourceAccessException | HttpServerErrorException ex) {
                attempt++;
                if (attempt > maxRetries) {
                    throw ex;
                }
                log.warn("COBOL bridge {} failed (attempt {}/{}): {} - retrying",
                        op, attempt, maxRetries, ex.getMessage());
                sleep();
            }
        }
    }

    private void sleep() {
        if (retryBackoffMs <= 0) {
            return;
        }
        try {
            Thread.sleep(retryBackoffMs);
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while backing off before bridge retry", ie);
        }
    }
}
