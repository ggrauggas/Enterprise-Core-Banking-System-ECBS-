package com.ecbs.account;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;
import com.ecbs.transaction.Transaction;
import com.ecbs.transaction.TransactionRepository;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
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

/** Web-layer tests for the accounts endpoints. */
@WebMvcTest(AccountController.class)
class AccountControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private AccountRepository repo;

    @MockBean
    private TransactionRepository transactions;

    @MockBean
    private BankingService banking;

    @BeforeEach
    void stubPayload() {
        when(banking.payload(any())).thenReturn(new HashMap<>());
    }

    private Account sample(long id, Account.Status status) {
        Account a = new Account();
        a.setCustomerId(1L);
        a.setIban("ES7600000000000000000000");
        a.setAccountType(Account.Type.CHECKING);
        a.setStatus(status);
        a.setBalance(new BigDecimal("100.00"));
        return a;
    }

    @Test
    void listAllWhenNoFilters() throws Exception {
        when(repo.findAll()).thenReturn(List.of(sample(1, Account.Status.ACTIVE)));
        mvc.perform(get("/api/v1/accounts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$[0].iban").value("ES7600000000000000000000"));
    }

    @Test
    void listPaginatedReturnsEnvelope() throws Exception {
        when(repo.search(any(), any(), any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(sample(1, Account.Status.ACTIVE)),
                        PageRequest.of(0, 25), 1));
        mvc.perform(get("/api/v1/accounts").param("page", "0").param("q", "ES76"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].iban").value("ES7600000000000000000000"));
    }

    @Test
    void listByCustomerAndStatusFilters() throws Exception {
        when(repo.findByCustomerIdAndStatus(1L, Account.Status.ACTIVE))
                .thenReturn(List.of(sample(1, Account.Status.ACTIVE)));
        mvc.perform(get("/api/v1/accounts").param("customerId", "1").param("status", "ACTIVE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void listByStatusOnlyUsesIndexedQuery() throws Exception {
        when(repo.findByStatus(Account.Status.CLOSED))
                .thenReturn(List.of(sample(2, Account.Status.CLOSED)));
        mvc.perform(get("/api/v1/accounts").param("status", "CLOSED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value("CLOSED"));
    }

    @Test
    void getMissingReturns404() throws Exception {
        when(repo.findById(7L)).thenReturn(Optional.empty());
        mvc.perform(get("/api/v1/accounts/7"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("E004"));
    }

    @Test
    void movementsReturnsHistory() throws Exception {
        when(repo.findById(3L)).thenReturn(Optional.of(sample(3, Account.Status.ACTIVE)));
        when(transactions.findByAccountIdOrderByTimestampDesc(3L)).thenReturn(List.of(new Transaction()));
        mvc.perform(get("/api/v1/accounts/3/transactions"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void openReturns201AndFetchesAccount() throws Exception {
        when(banking.execute(eq("ACCT-OPEN"), any())).thenReturn(Map.of("accountId", 5));
        when(repo.findById(5L)).thenReturn(Optional.of(sample(5, Account.Status.ACTIVE)));
        String body = """
                {"customerId":1,"accountType":"CHECKING"}""";
        mvc.perform(post("/api/v1/accounts").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    void openWithMissingCustomerReturns400() throws Exception {
        mvc.perform(post("/api/v1/accounts").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"accountType\":\"SAVINGS\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION"));
    }

    @Test
    void closeInvokesBridgeAndReturnsAccount() throws Exception {
        when(banking.execute(eq("ACCT-CLOSE"), any())).thenReturn(Map.of("status", "OK"));
        when(repo.findById(8L)).thenReturn(Optional.of(sample(8, Account.Status.CLOSED)));
        mvc.perform(post("/api/v1/accounts/8/close").header("X-ECBS-User", "teller"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CLOSED"));
        verify(banking).execute(eq("ACCT-CLOSE"), any());
    }

    @Test
    void closeMapsBusinessErrorFromBridge() throws Exception {
        when(banking.execute(eq("ACCT-CLOSE"), any()))
                .thenThrow(new BridgeException(HttpStatus.CONFLICT, "E007", "BALANCE NOT ZERO"));
        mvc.perform(post("/api/v1/accounts/9/close"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("E007"));
    }
}
