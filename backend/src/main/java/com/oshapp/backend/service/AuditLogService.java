package com.oshapp.backend.service;

import com.oshapp.backend.model.AuditLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;



public interface AuditLogService {
    Page<AuditLog> getAuditLogs(Pageable pageable);
    void logAction(String username,String action,String details);
}
