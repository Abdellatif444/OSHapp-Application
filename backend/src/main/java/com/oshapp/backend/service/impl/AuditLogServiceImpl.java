package com.oshapp.backend.service.impl;

import org.springframework.stereotype.Service;

import com.oshapp.backend.model.AuditLog;
import com.oshapp.backend.repository.AuditLogRepository;
import com.oshapp.backend.service.AuditLogService;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import org.springframework.beans.factory.annotation.Autowired;

@Service
@RequiredArgsConstructor
public class AuditLogServiceImpl implements AuditLogService {

    
    @Autowired
    private AuditLogRepository auditLogRepository;

    @Override
    public Page<AuditLog> getAuditLogs(Pageable pageable) {
        return auditLogRepository.findAllByOrderByTimestampDesc(pageable);
    }

    @Override
    public void logAction(String username, String action, String details) {
        AuditLog log = new AuditLog(username, action, details);
        auditLogRepository.save(log);
    }
}