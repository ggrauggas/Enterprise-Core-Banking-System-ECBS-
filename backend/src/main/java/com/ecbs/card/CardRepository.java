package com.ecbs.card;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CardRepository extends JpaRepository<Card, Long> {

    Optional<Card> findByCardNumber(String cardNumber);

    List<Card> findByAccountId(Long accountId);

    List<Card> findByStatus(Card.Status status);

    List<Card> findByAccountIdAndStatus(Long accountId, Card.Status status);

    /**
     * Paged search with optional account / status filters and an optional text
     * term ({@code q}, already wrapped in {@code %…%}, or null).
     */
    @Query("""
            SELECT c FROM Card c
            WHERE (:accountId IS NULL OR c.accountId = :accountId)
              AND (:status IS NULL OR c.status = :status)
              AND (:q IS NULL
                   OR c.cardNumber LIKE :q
                   OR CAST(c.cardId AS string) LIKE :q
                   OR CAST(c.accountId AS string) LIKE :q)
            """)
    Page<Card> search(@Param("accountId") Long accountId,
                      @Param("status") Card.Status status,
                      @Param("q") String q, Pageable pageable);
}
