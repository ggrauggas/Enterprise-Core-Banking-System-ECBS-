package com.ecbs.audit;

import java.util.HashMap;
import java.util.Map;

import com.ecbs.cobol.BankingService;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;

/** Web-layer tests for the audit trail viewer. */
@WebMvcTest(AuditController.class)
class AuditControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private BankingService banking;

    @BeforeEach
    void stubPayload() {
        when(banking.payload(any())).thenReturn(new HashMap<>());
    }

    @Test
    void queryForwardsAllFilters() throws Exception {
        when(banking.execute(eq("AUDIT-INQUIRY"), argThat(p ->
                p.containsKey("entityType") && p.containsKey("entityId")
                        && p.containsKey("username") && p.containsKey("operation")
                        && p.containsKey("dateFrom") && p.containsKey("dateTo")
                        && p.containsKey("limit"))))
                .thenReturn(Map.of("rows", java.util.List.of()));
        mvc.perform(get("/api/v1/audit")
                        .param("entityType", "CUSTOMER")
                        .param("entityId", "1")
                        .param("username", "admin")
                        .param("operation", "CREATE")
                        .param("dateFrom", "2026-01-01")
                        .param("dateTo", "2026-12-31")
                        .param("limit", "50"))
                .andExpect(status().isOk());
    }

    @Test
    void queryWithoutFiltersStillWorks() throws Exception {
        when(banking.execute(eq("AUDIT-INQUIRY"), any())).thenReturn(Map.of("rows", java.util.List.of()));
        mvc.perform(get("/api/v1/audit"))
                .andExpect(status().isOk());
    }

    @Test
    void statsEndpoint() throws Exception {
        when(banking.execute(eq("AUDIT-STATS"), any())).thenReturn(Map.of("total", 42));
        mvc.perform(get("/api/v1/audit/stats"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(42));
    }
}
