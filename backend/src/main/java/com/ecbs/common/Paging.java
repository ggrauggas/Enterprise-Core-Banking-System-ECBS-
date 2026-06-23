package com.ecbs.common;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/** Small helpers shared by the paginated list endpoints. */
public final class Paging {

    private static final int DEFAULT_SIZE = 25;
    private static final int MAX_SIZE = 200;

    private Paging() {
    }

    /** Builds a {@link Pageable} with safe bounds and a stable ascending sort. */
    public static Pageable of(Integer page, Integer size, String sortField) {
        int p = page == null ? 0 : Math.max(page, 0);
        int s = size == null ? DEFAULT_SIZE : Math.min(Math.max(size, 1), MAX_SIZE);
        return PageRequest.of(p, s, Sort.by(sortField).ascending());
    }

    /** Normalises a search term into a lower-cased {@code %…%} LIKE pattern, or null. */
    public static String like(String q) {
        if (q == null) {
            return null;
        }
        String trimmed = q.trim();
        return trimmed.isEmpty() ? null : "%" + trimmed.toLowerCase() + "%";
    }
}
