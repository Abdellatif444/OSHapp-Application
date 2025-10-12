package com.oshapp.backend.service;

import com.oshapp.backend.model.Setting;


import java.util.List;
import java.util.Map;

public interface SettingService {
    Map<String, String> getSettings();
    void updateSettings(List<Setting> settings);
}
