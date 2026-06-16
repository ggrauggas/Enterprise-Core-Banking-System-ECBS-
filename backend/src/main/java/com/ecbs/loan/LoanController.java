package com.ecbs.loan;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import com.ecbs.cobol.BankingService;
import com.ecbs.cobol.BridgeException;

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
@RequestMapping("/api/v1/loans")
@Tag(name = "Loans", description = "Loan simulation, application, approval and rejection")
public class LoanController {

    private final LoanRepository repo;
    private final BankingService banking;

    public LoanController(LoanRepository repo, BankingService banking) {
        this.repo = repo;
        this.banking = banking;
    }

    @GetMapping
    @Operation(summary = "List loans, optionally filtered by customer or status")
    public List<Loan> list(@RequestParam(required = false) Long customerId,
                           @RequestParam(required = false) Loan.Status status) {
        if (customerId != null) {
            List<Loan> base = repo.findByCustomerId(customerId);
            return status != null ? base.stream().filter(l -> l.getStatus() == status).toList() : base;
        }
        return status != null ? repo.findByStatus(status) : repo.findAll();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one loan by id")
    public Loan get(@PathVariable Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new BridgeException(HttpStatus.NOT_FOUND, "E004",
                        "Loan " + id + " not found"));
    }

    @GetMapping("/{id}/schedule")
    @Operation(summary = "French amortization schedule of a stored loan (COBOL LOAN-SIMULATE)")
    public Map<String, Object> schedule(@PathVariable Long id) {
        Map<String, Object> p = banking.payload(null);
        p.put("loanId", id);
        return banking.execute("LOAN-SIMULATE", p);
    }

    @PostMapping("/simulate")
    @Operation(summary = "Simulate a loan without storing it (COBOL LOAN-SIMULATE)")
    public Map<String, Object> simulate(@Valid @RequestBody SimulateRequest req) {
        Map<String, Object> p = banking.payload(null);
        p.put("amount", req.amount());
        p.put("interestRate", req.interestRate());
        p.put("durationMonths", req.durationMonths());
        return banking.execute("LOAN-SIMULATE", p);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Apply for a loan (COBOL LOAN-REQUEST)")
    public Loan request(@Valid @RequestBody RequestLoan req,
                        @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("customerId", req.customerId());
        p.put("amount", req.amount());
        p.put("interestRate", req.interestRate());
        p.put("durationMonths", req.durationMonths());
        Map<String, Object> data = banking.execute("LOAN-REQUEST", p);
        return fetch(BankingService.asLong(data.get("loanId")));
    }

    @PostMapping("/{id}/approve")
    @Operation(summary = "Approve a loan, optionally disbursing to an account (COBOL LOAN-APPROVE)")
    public Loan approve(@PathVariable Long id, @RequestBody(required = false) ApproveRequest req,
                        @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("loanId", id);
        if (req != null && req.accountId() != null) {
            p.put("accountId", req.accountId());
        }
        banking.execute("LOAN-APPROVE", p);
        return fetch(id);
    }

    @PostMapping("/{id}/reject")
    @Operation(summary = "Reject a loan (COBOL LOAN-REJECT)")
    public Loan reject(@PathVariable Long id, @RequestBody(required = false) RejectRequest req,
                       @RequestHeader(value = "X-ECBS-User", required = false) String user) {
        Map<String, Object> p = banking.payload(user);
        p.put("loanId", id);
        if (req != null && req.reason() != null) {
            p.put("reason", req.reason());
        }
        banking.execute("LOAN-REJECT", p);
        return fetch(id);
    }

    private Loan fetch(Long id) {
        return repo.findById(id).orElseThrow(() ->
                new BridgeException(HttpStatus.INTERNAL_SERVER_ERROR, "E010",
                        "Loan " + id + " not found after operation"));
    }

    public record SimulateRequest(
            @NotNull @Positive BigDecimal amount,
            @NotNull BigDecimal interestRate,
            @NotNull @Positive Integer durationMonths) {
    }

    public record RequestLoan(
            @NotNull Long customerId,
            @NotNull @Positive BigDecimal amount,
            @NotNull BigDecimal interestRate,
            @NotNull @Positive Integer durationMonths) {
    }

    public record ApproveRequest(Long accountId) {
    }

    public record RejectRequest(String reason) {
    }
}
