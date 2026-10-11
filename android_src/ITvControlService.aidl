package com.hyouka.tvcontrol;

interface ITvControlService {
    int getBrightnessPercent() = 1;
    void setBrightnessPercent(int percent) = 2;
    int getVolumePercent(int stream) = 3;
    void setVolumePercent(int stream, int percent) = 4;
    int getScreenTimeoutMillis() = 5;
    void setScreenTimeoutMillis(int timeoutMillis) = 6;
    String getDeviceInfo() = 7;
    void destroy() = 16777114;
}
