package com.ecbs.report;

import java.util.Map;

import com.ecbs.cobol.BankingService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Reporting endpoints. Each one triggers the matching COBOL reporting
 * program, which returns the JSON data and (for bank/account) also
 * writes the CSV and PDF exports inside the cobol-runtime container.
 */
@RestController
@RequestMapping("/api/v1/reports")
@Tag(name = "Reports", description = "Bank, customer and account reports (CSV/PDF exported by COBOL)")
public class ReportController {

    private final BankingService banking;

    public ReportController(BankingService banking) {
        this.banking = banking;
    }

    @GetMapping("/bank")
    @Operation(summary = "Bank-wide totals (COBOL RPT-BANK, exports CSV+PDF)")
    public Map<String, Object> bank() {
        return banking.execute("RPT-BANK", banking.payload(null));
    }

    @GetMapping("/customers/{id}")
    @Operation(summary = "Full customer statement (COBOL RPT-CUSTOMER)")
    public Map<String, Object> customer(@PathVariable Long id) {
        Map<String, Object> p = banking.payload(null);
        p.put("customerId", id);
        return banking.execute("RPT-CUSTOMER", p);
    }

    @GetMapping("/accounts/{id}")
    @Operation(summary = "Account statement (COBOL RPT-ACCOUNT, exports CSV+PDF)")
    public Map<String, Object> account(@PathVariable Long id,
                                       @RequestParam(required = false) Integer limit) {
        Map<String, Object> p = banking.payload(null);
        p.put("accountId", id);
        if (limit != null) p.put("limit", limit);
        return banking.execute("RPT-ACCOUNT", p);
    }
}
