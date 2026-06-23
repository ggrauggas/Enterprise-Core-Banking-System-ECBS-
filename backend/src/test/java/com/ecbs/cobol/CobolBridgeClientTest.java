package com.ecbs.cobol;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import com.sun.net.httpserver.HttpServer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.HttpServerErrorException;

/**
 * Tests the {@link CobolBridgeClient} against a real in-process HTTP
 * server, exercising the JSON round-trip, the request routing and the
 * transient-failure retry, without needing the cobol-runtime container.
 */
class CobolBridgeClientTest {

    private HttpServer server;
    private CobolBridgeClient client;
    private final AtomicReference<String> lastPath = new AtomicReference<>();
    private final AtomicReference<String> lastBody = new AtomicReference<>();
    private final AtomicInteger flakyAttempts = new AtomicInteger();
    private final AtomicInteger alwaysDownAttempts = new AtomicInteger();

    @BeforeEach
    void startServer() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/health", exchange -> respond(exchange, 200,
                "{\"status\":\"UP\"}"));
        server.createContext("/run/CUST-CREATE", exchange -> {
            lastPath.set(exchange.getRequestURI().getPath());
            lastBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            respond(exchange, 200, "{\"data\":{\"status\":\"OK\"}}");
        });
        // Fails twice with 503, then succeeds: exercises the retry path.
        server.createContext("/run/FLAKY", exchange -> {
            exchange.getRequestBody().readAllBytes();
            if (flakyAttempts.incrementAndGet() <= 2) {
                respond(exchange, 503, "{\"error\":\"warming up\"}");
            } else {
                respond(exchange, 200, "{\"data\":{\"status\":\"OK\"}}");
            }
        });
        // Always 503: retries are exhausted and the error propagates.
        server.createContext("/run/DOWN", exchange -> {
            exchange.getRequestBody().readAllBytes();
            alwaysDownAttempts.incrementAndGet();
            respond(exchange, 503, "{\"error\":\"down\"}");
        });
        server.start();
        String baseUrl = "http://127.0.0.1:" + server.getAddress().getPort();
        // 2 retries, tiny backoff to keep the test fast.
        client = new CobolBridgeClient(baseUrl, 2000, 5000, 2, 5);
    }

    @AfterEach
    void stopServer() {
        server.stop(0);
    }

    private static void respond(com.sun.net.httpserver.HttpExchange exchange, int status, String json)
            throws IOException {
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }

    @Test
    void healthReturnsParsedBody() {
        Map<String, Object> health = client.health();
        assertThat(health).containsEntry("status", "UP");
    }

    @Test
    void runProgramPostsToProgramPathWithJsonBody() {
        Map<String, Object> response = client.runProgram("CUST-CREATE", Map.of("firstName", "Ada"));
        assertThat(response).containsKey("data");
        assertThat(lastPath.get()).isEqualTo("/run/CUST-CREATE");
        assertThat(lastBody.get()).contains("\"firstName\":\"Ada\"");
    }

    @Test
    void retriesTransientServerErrorsThenSucceeds() {
        Map<String, Object> response = client.runProgram("FLAKY", Map.of());
        assertThat(response).containsKey("data");
        assertThat(flakyAttempts.get()).isEqualTo(3); // 2 failures + 1 success
    }

    @Test
    void propagatesErrorAfterRetriesAreExhausted() {
        assertThatThrownBy(() -> client.runProgram("DOWN", Map.of()))
                .isInstanceOf(HttpServerErrorException.class);
        assertThat(alwaysDownAttempts.get()).isEqualTo(3); // initial + 2 retries
    }
}
