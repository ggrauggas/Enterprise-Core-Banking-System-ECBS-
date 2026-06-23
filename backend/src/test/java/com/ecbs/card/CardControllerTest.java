package com.ecbs.card;

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

/** Web-layer tests for card issuing, blocking, purchases and refunds. */
@WebMvcTest(CardController.class)
class CardControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private CardRepository repo;

    @MockBean
    private BankingService banking;

    @BeforeEach
    void stubPayload() {
        when(banking.payload(any())).thenReturn(new HashMap<>());
    }

    private Card sample(Card.Status status) {
        Card c = new Card();
        c.setAccountId(1L);
        c.setCardNumber("4111111111111111");
        c.setCreditLimit(new BigDecimal("1000.00"));
        c.setAvailableCredit(new BigDecimal("1000.00"));
        c.setStatus(status);
        return c;
    }

    @Test
    void listPaginatedReturnsEnvelope() throws Exception {
        when(repo.search(any(), any(), any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(sample(Card.Status.ACTIVE)), PageRequest.of(0, 25), 1));
        mvc.perform(get("/api/v1/cards").param("page", "0").param("q", "4111"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].cardNumber").value("4111111111111111"));
    }

    @Test
    void listFiltersByAccountAndStatus() throws Exception {
        when(repo.findByAccountIdAndStatus(1L, Card.Status.BLOCKED))
                .thenReturn(List.of(sample(Card.Status.BLOCKED)));
        mvc.perform(get("/api/v1/cards").param("accountId", "1").param("status", "BLOCKED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void listByStatusOnlyUsesIndexedQuery() throws Exception {
        when(repo.findByStatus(Card.Status.ACTIVE)).thenReturn(List.of(sample(Card.Status.ACTIVE)));
        mvc.perform(get("/api/v1/cards").param("status", "ACTIVE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void listAllWhenNoFilter() throws Exception {
        when(repo.findAll()).thenReturn(List.of(sample(Card.Status.ACTIVE)));
        mvc.perform(get("/api/v1/cards"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void getMissingReturns404() throws Exception {
        when(repo.findById(2L)).thenReturn(Optional.empty());
        mvc.perform(get("/api/v1/cards/2"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("E004"));
    }

    @Test
    void issueReturns201() throws Exception {
        when(banking.execute(eq("CARD-ISSUE"), any())).thenReturn(Map.of("cardId", 3));
        when(repo.findById(3L)).thenReturn(Optional.of(sample(Card.Status.ACTIVE)));
        mvc.perform(post("/api/v1/cards").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"accountId\":1,\"creditLimit\":1000.00}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.cardNumber").value("4111111111111111"));
    }

    @Test
    void blockAndUnblock() throws Exception {
        when(banking.execute(eq("CARD-BLOCK"), any())).thenReturn(Map.of("status", "OK"));
        when(banking.execute(eq("CARD-UNBLOCK"), any())).thenReturn(Map.of("status", "OK"));
        when(repo.findById(4L)).thenReturn(Optional.of(sample(Card.Status.BLOCKED)));
        mvc.perform(post("/api/v1/cards/4/block")).andExpect(status().isOk());
        mvc.perform(post("/api/v1/cards/4/unblock")).andExpect(status().isOk());
    }

    @Test
    void purchaseReturns201() throws Exception {
        when(banking.execute(eq("CARD-PURCHASE"), any())).thenReturn(Map.of("status", "OK"));
        mvc.perform(post("/api/v1/cards/5/purchases").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":20.00,\"description\":\"shop\"}"))
                .andExpect(status().isCreated());
    }

    @Test
    void refundOverLimitMapsTo422() throws Exception {
        when(banking.execute(eq("CARD-REFUND"), any()))
                .thenThrow(new BridgeException(HttpStatus.UNPROCESSABLE_ENTITY, "E009", "REFUND EXCEEDS"));
        mvc.perform(post("/api/v1/cards/5/refunds").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":20.00}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.errorCode").value("E009"));
    }
}
