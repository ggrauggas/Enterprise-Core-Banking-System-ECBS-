package com.ecbs.audit;

import java.util.Map;

import com.ecbs.cobol.BankingService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/audit")
@Tag(name = "Audit", description = "Audit trail viewer and statistics")
public class AuditController {

    private final BankingService banking;

    public AuditController(BankingService banking) {
        this.banking = banking;
    }

    @GetMapping
    @Operation(summary = "Query the audit trail with combinable filters (COBOL AUDIT-INQUIRY)")
    public Map<String, Object> query(@RequestParam(required = false) String entityType,
                                     @RequestParam(required = false) Long entityId,
                                     @RequestParam(required = false) String username,
                                     @RequestParam(required = false) String operation,
                                     @RequestParam(required = false) String dateFrom,
                                     @RequestParam(required = false) String dateTo,
                                     @RequestParam(required = false) Integer limit) {
        Map<String, Object> p = banking.payload(null);
        if (entityType != null) p.put("entityType", entityType);
        if (entityId != null) p.put("entityId", entityId);
        if (username != null) p.put("username", username);
        if (operation != null) p.put("operation", operation);
        if (dateFrom != null) p.put("dateFrom", dateFrom);
        if (dateTo != null) p.put("dateTo", dateTo);
        if (limit != null) p.put("limit", limit);
        return banking.execute("AUDIT-INQUIRY", p);
    }

    @GetMapping("/stats")
    @Operation(summary = "Aggregated audit statistics (COBOL AUDIT-STATS)")
    public Map<String, Object> stats() {
        return banking.execute("AUDIT-STATS", banking.payload(null));
    }
}
