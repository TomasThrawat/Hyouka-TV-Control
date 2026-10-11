package com.hyouka.hyouka_tv_control

import android.content.Context
import android.os.Build
import android.os.Process
import com.hyouka.tvcontrol.ITvControlService
import java.io.IOException

class TvControlUserService(@Suppress("UNUSED_PARAMETER") context: Context? = null) : ITvControlService.Stub() {
    override fun getBrightnessPercent(): Int {
        val raw = runShell("settings get system screen_brightness").toIntOrNull() ?: 128
        return ((raw.coerceIn(1, 255) * 100.0) / 255.0).toInt().coerceIn(1, 100)
    }

    override fun setBrightnessPercent(percent: Int) {
        val safe = percent.coerceIn(1, 100)
        val raw = ((safe * 255.0) / 100.0).toInt().coerceIn(1, 255)
        runShell("settings put system screen_brightness_mode 0 && settings put system screen_brightness " + raw)
    }

    override fun getVolumePercent(stream: Int): Int {
        val state = readVolumeState(stream)
        if (state.second <= 0) return 0
        return ((state.first * 100.0) / state.second).toInt().coerceIn(0, 100)
    }

    override fun setVolumePercent(stream: Int, percent: Int) {
        val safeStream = validateStream(stream)
        val safePercent = percent.coerceIn(0, 100)
        val max = readVolumeState(safeStream).second.coerceAtLeast(1)
        val index = ((max * safePercent) / 100).coerceIn(0, max)
        try {
            runShell("media volume --stream " + safeStream + " --set " + index)
        } catch (_: Exception) {
            runShell("cmd media_session volume --stream " + safeStream + " --set " + index)
        }
    }

    override fun getScreenTimeoutMillis(): Int =
        runShell("settings get system screen_off_timeout").toIntOrNull() ?: 600000

    override fun setScreenTimeoutMillis(timeoutMillis: Int) {
        val safe = timeoutMillis.coerceIn(60000, 3600000)
        runShell("settings put system screen_off_timeout " + safe)
    }

    override fun getDeviceInfo(): String =
        Build.MANUFACTURER + " " + Build.MODEL + " | Android " +
            Build.VERSION.RELEASE + " | SDK " + Build.VERSION.SDK_INT +
            " | service UID " + Process.myUid()

    override fun destroy() { System.exit(0) }

    private fun validateStream(stream: Int): Int {
        if (stream !in listOf(1, 2, 3, 4, 5)) {
            throw IllegalArgumentException("Unsupported audio stream")
        }
        return stream
    }

    private fun readVolumeState(stream: Int): Pair<Int, Int> {
        val safeStream = validateStream(stream)
        val output = try {
            runShell("media volume --stream " + safeStream + " --get")
        } catch (_: Exception) {
            runShell("cmd media_session volume --stream " + safeStream + " --get")
        }
        val match = Regex(
            "volume is\\s*(-?\\d+)\\s+in range\\s*\\[(-?\\d+)\\.\\.(-?\\d+)\\]",
            RegexOption.IGNORE_CASE
        ).find(output)
        if (match != null) {
            val current = match.groupValues[1].toInt()
            val minimum = match.groupValues[2].toInt()
            val maximum = match.groupValues[3].toInt()
            val range = (maximum - minimum).coerceAtLeast(1)
            return (current - minimum).coerceIn(0, range) to range
        }
        throw IOException("Could not read Android volume state: " + output.take(180))
    }

    private fun runShell(command: String): String {
        val process = ProcessBuilder("sh", "-c", command)
            .redirectErrorStream(true)
            .start()
        val output = process.inputStream.bufferedReader().use { it.readText() }.trim()
        val exitCode = process.waitFor()
        if (exitCode != 0) {
            throw IOException("Command failed (" + exitCode + "): " + output.take(180))
        }
        return output
    }
}
