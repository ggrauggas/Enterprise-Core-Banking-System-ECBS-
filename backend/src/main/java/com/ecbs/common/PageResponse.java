package com.ecbs.common;

import java.util.List;

import org.springframework.data.domain.Page;

/**
 * Stable, explicit pagination envelope returned by the list endpoints when a
 * {@code page} parameter is supplied.
 *
 * <p>Spring's default serialization of {@code Page}/{@code PageImpl} is marked
 * unstable in Boot 3.x; this record pins the wire contract the frontend relies
 * on ({@code content} + {@code totalElements}).</p>
 */
public record PageResponse<T>(List<T> content, long totalElements, int page, int size) {

    public static <T> PageResponse<T> of(Page<T> page) {
        return new PageResponse<>(page.getContent(), page.getTotalElements(),
                page.getNumber(), page.getSize());
    }
}
