package com.oshapp.backend.service.impl;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import com.oshapp.backend.model.Setting;
import com.oshapp.backend.repository.SettingRepository;
import com.oshapp.backend.service.SettingService;

import org.springframework.stereotype.Service;

@Service
public class SettingServiceImpl implements SettingService {
    
    @Autowired
    private SettingRepository settingRepository;

    @Transactional(readOnly = true)
    public Map<String, String> getSettings() {
        return settingRepository.findAll().stream()
                .collect(Collectors.toMap(Setting::getKey, Setting::getValue));
    }

    @Transactional
    public void updateSettings(List<Setting> settings) {
        settingRepository.saveAll(settings);
    }
}
