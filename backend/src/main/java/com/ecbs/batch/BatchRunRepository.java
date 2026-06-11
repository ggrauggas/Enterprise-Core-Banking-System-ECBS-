package com.ecbs.batch;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface BatchRunRepository extends JpaRepository<BatchRun, Long> {

    List<BatchRun> findByOrderByStartedAtDesc();
}
