package com.ecbs.account;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AccountRepository extends JpaRepository<Account, Long> {

    Optional<Account> findByIban(String iban);

    List<Account> findByCustomerId(Long customerId);

    List<Account> findByStatus(Account.Status status);

    List<Account> findByCustomerIdAndStatus(Long customerId, Account.Status status);

    /**
     * Paged search with optional customer / status filters and an optional text
     * term ({@code q}, already lower-cased and wrapped in {@code %…%}, or null).
     */
    @Query("""
            SELECT a FROM Account a
            WHERE (:customerId IS NULL OR a.customerId = :customerId)
              AND (:status IS NULL OR a.status = :status)
              AND (:q IS NULL
                   OR LOWER(a.iban) LIKE :q
                   OR CAST(a.accountId AS string) LIKE :q
                   OR CAST(a.customerId AS string) LIKE :q)
            """)
    Page<Account> search(@Param("customerId") Long customerId,
                         @Param("status") Account.Status status,
                         @Param("q") String q, Pageable pageable);
}
