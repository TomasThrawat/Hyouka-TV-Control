package com.hyouka.tvcontrol;

interface ITvControlService {
    int getBrightnessPercent();
    void setBrightnessPercent(int percent);
    int getVolumePercent(int stream);
    void setVolumePercent(int stream, int percent);
    int getScreenTimeoutMillis();
    void setScreenTimeoutMillis(int timeoutMillis);
    String getDeviceInfo();
    void destroy();
}
