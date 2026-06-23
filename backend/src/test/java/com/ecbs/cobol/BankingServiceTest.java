package com.ecbs.cobol;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.http.HttpStatus;

/** Unit tests for the COBOL result envelope interpretation and error mapping. */
class BankingServiceTest {

    private final CobolBridgeClient bridge = mock(CobolBridgeClient.class);
    private final BankingService service = new BankingService(bridge);

    @Test
    void returnsDataOnSuccess() {
        when(bridge.runProgram(eq("CUST-CREATE"), anyMap()))
                .thenReturn(Map.of("data", Map.of("status", "OK", "customerId", 7)));

        Map<String, Object> data = service.execute("CUST-CREATE", new HashMap<>());

        assertThat(data.get("customerId")).isEqualTo(7);
    }

    @ParameterizedTest
    @CsvSource({
            "E001,BAD_REQUEST",
            "E011,BAD_REQUEST",
            "E004,NOT_FOUND",
            "E003,CONFLICT",
            "E007,CONFLICT",
            "E022,CONFLICT",
            "E005,UNPROCESSABLE_ENTITY",
            "E009,UNPROCESSABLE_ENTITY",
            "E010,INTERNAL_SERVER_ERROR",
            "E999,INTERNAL_SERVER_ERROR",
    })
    void mapsErrorCodeToHttpStatus(String code, HttpStatus expected) {
        when(bridge.runProgram(any(), anyMap()))
                .thenReturn(Map.of("data", Map.of("status", "ERROR", "errorCode", code, "message", "boom")));

        assertThatThrownBy(() -> service.execute("P", new HashMap<>()))
                .isInstanceOf(BridgeException.class)
                .satisfies(e -> {
                    BridgeException be = (BridgeException) e;
                    assertThat(be.getStatus()).isEqualTo(expected);
                    assertThat(be.getErrorCode()).isEqualTo(code);
                });
    }

    @Test
    void missingDataYieldsBadGateway() {
        when(bridge.runProgram(any(), anyMap())).thenReturn(Map.of("stderr", "no json"));

        assertThatThrownBy(() -> service.execute("P", new HashMap<>()))
                .isInstanceOf(BridgeException.class)
                .satisfies(e -> assertThat(((BridgeException) e).getStatus()).isEqualTo(HttpStatus.BAD_GATEWAY));
    }

    @Test
    void bridgeExceptionWrappedAsBadGateway() {
        when(bridge.runProgram(any(), anyMap())).thenThrow(new RuntimeException("connection refused"));

        assertThatThrownBy(() -> service.execute("P", new HashMap<>()))
                .isInstanceOf(BridgeException.class)
                .satisfies(e -> assertThat(((BridgeException) e).getStatus()).isEqualTo(HttpStatus.BAD_GATEWAY));
    }

    @Test
    void payloadCarriesUser() {
        assertThat(service.payload("alice")).containsEntry("user", "alice");
        assertThat(service.payload(null)).doesNotContainKey("user");
    }

    @Test
    void asLongReadsNumbers() {
        assertThat(BankingService.asLong(7)).isEqualTo(7L);
        assertThat(BankingService.asLong(9L)).isEqualTo(9L);
    }
}
