package com.ecbs.loan;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/** Web-layer tests for loan simulation, application, approval and rejection. */
@WebMvcTest(LoanController.class)
class LoanControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private LoanRepository repo;

    @MockBean
    private BankingService banking;

    @BeforeEach
    void stubPayload() {
        when(banking.payload(any())).thenReturn(new HashMap<>());
    }

    private Loan sample(Loan.Status status) {
        Loan l = new Loan();
        l.setCustomerId(1L);
        l.setAmount(new BigDecimal("10000.00"));
        l.setInterestRate(new BigDecimal("5.00"));
        l.setDurationMonths(12);
        l.setStatus(status);
        return l;
    }

    @Test
    void listPaginatedReturnsEnvelope() throws Exception {
        when(repo.search(any(), any(), any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(sample(Loan.Status.REQUESTED)), PageRequest.of(0, 25), 1));
        mvc.perform(get("/api/v1/loans").param("page", "0").param("q", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray())
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void listByStatus() throws Exception {
        when(repo.findByStatus(Loan.Status.REQUESTED)).thenReturn(List.of(sample(Loan.Status.REQUESTED)));
        mvc.perform(get("/api/v1/loans").param("status", "REQUESTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void listByCustomerAndStatus() throws Exception {
        when(repo.findByCustomerIdAndStatus(1L, Loan.Status.APPROVED))
                .thenReturn(List.of(sample(Loan.Status.APPROVED)));
        mvc.perform(get("/api/v1/loans").param("customerId", "1").param("status", "APPROVED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void listByCustomerOnly() throws Exception {
        when(repo.findByCustomerId(1L)).thenReturn(List.of(sample(Loan.Status.REQUESTED)));
        mvc.perform(get("/api/v1/loans").param("customerId", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void listAll() throws Exception {
        when(repo.findAll()).thenReturn(List.of(sample(Loan.Status.ACTIVE)));
        mvc.perform(get("/api/v1/loans"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void getMissingReturns404() throws Exception {
        when(repo.findById(9L)).thenReturn(Optional.empty());
        mvc.perform(get("/api/v1/loans/9"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("E004"));
    }

    @Test
    void simulateReturnsSchedule() throws Exception {
        when(banking.execute(eq("LOAN-SIMULATE"), any())).thenReturn(Map.of("monthlyPayment", 856));
        mvc.perform(post("/api/v1/loans/simulate").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":10000,\"interestRate\":5,\"durationMonths\":12}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.monthlyPayment").value(856));
    }

    @Test
    void scheduleOfStoredLoan() throws Exception {
        when(banking.execute(eq("LOAN-SIMULATE"), any())).thenReturn(Map.of("rows", List.of()));
        mvc.perform(get("/api/v1/loans/7/schedule"))
                .andExpect(status().isOk());
    }

    @Test
    void requestReturns201() throws Exception {
        when(banking.execute(eq("LOAN-REQUEST"), any())).thenReturn(Map.of("loanId", 11));
        when(repo.findById(11L)).thenReturn(Optional.of(sample(Loan.Status.REQUESTED)));
        mvc.perform(post("/api/v1/loans").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"customerId\":1,\"amount\":10000,\"interestRate\":5,\"durationMonths\":12}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("REQUESTED"));
    }

    @Test
    void approveWithDisbursement() throws Exception {
        when(banking.execute(eq("LOAN-APPROVE"), any())).thenReturn(Map.of("status", "OK"));
        when(repo.findById(11L)).thenReturn(Optional.of(sample(Loan.Status.APPROVED)));
        mvc.perform(post("/api/v1/loans/11/approve").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"accountId\":2}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void approveWithoutBody() throws Exception {
        when(banking.execute(eq("LOAN-APPROVE"), any())).thenReturn(Map.of("status", "OK"));
        when(repo.findById(11L)).thenReturn(Optional.of(sample(Loan.Status.APPROVED)));
        mvc.perform(post("/api/v1/loans/11/approve"))
                .andExpect(status().isOk());
    }

    @Test
    void rejectWithReason() throws Exception {
        when(banking.execute(eq("LOAN-REJECT"), any())).thenReturn(Map.of("status", "OK"));
        when(repo.findById(11L)).thenReturn(Optional.of(sample(Loan.Status.REJECTED)));
        mvc.perform(post("/api/v1/loans/11/reject").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"low score\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("REJECTED"));
    }

    @Test
    void rejectAlreadyApprovedMapsToConflict() throws Exception {
        when(banking.execute(eq("LOAN-REJECT"), any()))
                .thenThrow(new BridgeException(HttpStatus.CONFLICT, "E014", "LOAN NOT PENDING"));
        mvc.perform(post("/api/v1/loans/11/reject"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("E014"));
    }
}
