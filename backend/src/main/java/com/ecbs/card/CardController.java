package com.ecbs.card;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;
import com.ecbs.common.PageResponse;
import com.ecbs.common.Paging;

import org.springframework.data.domain.Page;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/cards")
@Tag(name = "Cards", description = "Card issuing, blocking, purchases and refunds")
public class CardController {

    private final CardRepository repo;
    private final BankingService banking;

    public CardController(CardRepository repo, BankingService banking) {
        this.repo = repo;
        this.banking = banking;
    }

    @GetMapping
    @Operation(summary = "List cards; paginated when 'page' is given, optional account/status/q filters")
    public Object list(@RequestParam(required = false) Long accountId,
                       @RequestParam(required = false) Card.Status status,
                       @RequestParam(required = false) String q,
                       @RequestParam(required = false) Integer page,
                       @RequestParam(required = false) Integer size) {
        if (page != null) {
            Page<Card> result = repo.search(accountId, status, Paging.like(q),
                    Paging.of(page, size, "cardId"));
            return PageResponse.of(result);
        }
        // Index-backed filtering (Fase 15) rather than scanning every card.
        if (accountId != null && status != null) {
            return repo.findByAccountIdAndStatus(accountId, status);
        }
        if (accountId != null) {
            return repo.findByAccountId(accountId);
        }
        if (status != null) {
            return repo.findByStatus(status);
        }
        return repo.findAll();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one card by id")
    public Card get(@PathVariable Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new BridgeException(HttpStatus.NOT_FOUND, "E004",
                        "Card " + id + " not found"));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Issue a card (COBOL CARD-ISSUE, Luhn number)")
    public Card issue(@Valid @RequestBody IssueRequest req,
                      @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("accountId", req.accountId());
        p.put("creditLimit", req.creditLimit());
        Map<String, Object> data = banking.execute("CARD-ISSUE", p);
        return fetch(BankingService.asLong(data.get("cardId")));
    }

    @PostMapping("/{id}/block")
    @Operation(summary = "Block a card (COBOL CARD-BLOCK)")
    public Card block(@PathVariable Long id,
                      @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("cardId", id);
        banking.execute("CARD-BLOCK", p);
        return fetch(id);
    }

    @PostMapping("/{id}/unblock")
    @Operation(summary = "Unblock a card (COBOL CARD-UNBLOCK)")
    public Card unblock(@PathVariable Long id,
                        @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("cardId", id);
        banking.execute("CARD-UNBLOCK", p);
        return fetch(id);
    }

    @PostMapping("/{id}/purchases")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Card purchase (COBOL CARD-PURCHASE)")
    public Map<String, Object> purchase(@PathVariable Long id, @Valid @RequestBody AmountRequest req,
                                        @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("cardId", id);
        p.put("amount", req.amount());
        if (req.description() != null) p.put("description", req.description());
        return banking.execute("CARD-PURCHASE", p);
    }

    @PostMapping("/{id}/refunds")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Card refund (COBOL CARD-REFUND)")
    public Map<String, Object> refund(@PathVariable Long id, @Valid @RequestBody AmountRequest req,
                                      @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("cardId", id);
        p.put("amount", req.amount());
        if (req.description() != null) p.put("description", req.description());
        return banking.execute("CARD-REFUND", p);
    }

    private Card fetch(Long id) {
        return repo.findById(id).orElseThrow(() ->
                new BridgeException(HttpStatus.INTERNAL_SERVER_ERROR, "E010",
                        "Card " + id + " not found after operation"));
    }

    public record IssueRequest(
            @NotNull Long accountId,
            @NotNull @Positive BigDecimal creditLimit) {
    }

    public record AmountRequest(
            @NotNull @Positive BigDecimal amount,
            String description) {
    }
}
