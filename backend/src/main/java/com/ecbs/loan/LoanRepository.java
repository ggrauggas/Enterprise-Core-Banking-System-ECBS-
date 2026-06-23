package com.ecbs.loan;

import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LoanRepository extends JpaRepository<Loan, Long> {

    List<Loan> findByCustomerId(Long customerId);

    List<Loan> findByStatus(Loan.Status status);

    List<Loan> findByCustomerIdAndStatus(Long customerId, Loan.Status status);

    /**
     * Paged search with optional customer / status filters and an optional text
     * term ({@code q}, already wrapped in {@code %…%}, or null).
     */
    @Query("""
            SELECT l FROM Loan l
            WHERE (:customerId IS NULL OR l.customerId = :customerId)
              AND (:status IS NULL OR l.status = :status)
              AND (:q IS NULL
                   OR CAST(l.loanId AS string) LIKE :q
                   OR CAST(l.customerId AS string) LIKE :q)
            """)
    Page<Loan> search(@Param("customerId") Long customerId,
                      @Param("status") Loan.Status status,
                      @Param("q") String q, Pageable pageable);
}
