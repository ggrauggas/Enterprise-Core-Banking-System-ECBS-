package com.ecbs.cobol;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Client for the COBOL bridge running inside the cobol-runtime container.
 * Every business operation that must go through the COBOL layer is
 * dispatched here, mimicking how a middleware would route requests to
 * CICS transactions.
 */
@Component
public class CobolBridgeClient {

    private final RestClient restClient;

    public CobolBridgeClient(@Value("${ecbs.cobol-bridge.url}") String bridgeUrl) {
        this.restClient = RestClient.builder().baseUrl(bridgeUrl).build();
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> health() {
        return restClient.get()
                .uri("/health")
                .retrieve()
                .body(Map.class);
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> runProgram(String programName, Map<String, Object> payload) {
        return restClient.post()
                .uri("/run/{program}", programName)
                .body(payload)
                .retrieve()
                .body(Map.class);
    }
}
