package com.oshapp.backend.controller;

import com.oshapp.backend.model.Setting;
import com.oshapp.backend.service.SettingService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/admin/settings")
@PreAuthorize("hasRole('ROLE_ADMIN')")
public class SettingController {

    @Autowired
    private SettingService settingService;

    @GetMapping
    public ResponseEntity<Map<String, String>> getSettings() {
        return ResponseEntity.ok(settingService.getSettings());
    }

    @PutMapping
    public ResponseEntity<Void> updateSettings(@RequestBody List<Setting> settings) {
        settingService.updateSettings(settings);
        return ResponseEntity.ok().build();
    }
}
