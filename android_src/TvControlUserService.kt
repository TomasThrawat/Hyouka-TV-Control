package com.hyouka.hyouka_tv_control

import android.content.Context
import androidx.annotation.Keep
import android.os.Build
import android.os.Process
import com.hyouka.tvcontrol.ITvControlService
import java.io.IOException
import kotlin.math.abs

class TvControlUserService() : ITvControlService.Stub() {
    @Keep
    constructor(@Suppress("UNUSED_PARAMETER") context: Context) : this()

    private data class VolumeState(val current: Int, val minimum: Int, val maximum: Int) {
        val range: Int get() = (maximum - minimum).coerceAtLeast(1)
        val percent: Int get() = (((current - minimum).coerceIn(0, range) * 100.0) / range).toInt().coerceIn(0, 100)
    }

    override fun getBrightnessPercent(): Int {
        val raw = runShell("/system/bin/settings get system screen_brightness").toIntOrNull()
            ?: throw IOException("Android did not return a numeric screen brightness setting.")
        return ((raw.coerceIn(1, 255) * 100.0) / 255.0).toInt().coerceIn(1, 100)
    }

    override fun setBrightnessPercent(percent: Int) {
        val safe = percent.coerceIn(1, 100)
        val raw = ((safe * 255.0) / 100.0).toInt().coerceIn(1, 255)
        try {
            runShell("/system/bin/cmd display set-brightness " + (safe / 100.0f))
        } catch (_: Exception) {
            // Some TV firmwares omit this DisplayManager command; try the standard system setting below.
        }
        runShell("/system/bin/settings put system screen_brightness_mode 0 && /system/bin/settings put system screen_brightness " + raw)
        val actual = runShell("/system/bin/settings get system screen_brightness").toIntOrNull()
        if (actual != raw) {
            throw IOException("Brightness write was not retained by Android (requested $raw, read back ${actual ?: "unknown"}).")
        }
    }

    override fun getVolumePercent(stream: Int): Int = readVolumeState(stream).percent

    override fun setVolumePercent(stream: Int, percent: Int) {
        val safeStream = validateStream(stream)
        val safePercent = percent.coerceIn(0, 100)
        val before = readVolumeState(safeStream)
        val target = before.minimum + ((before.range * safePercent) / 100)
        runShell("/system/bin/cmd media_session volume --show --stream " + safeStream + " --set " + target)
        val after = readVolumeState(safeStream)
        if (abs(after.current - target) > 1) {
            throw IOException("Android did not apply the requested volume for stream $safeStream (requested index $target, actual ${after.current}, range ${after.minimum}..${after.maximum}).")
        }
    }

    override fun getScreenTimeoutMillis(): Int =
        runShell("/system/bin/settings get system screen_off_timeout").toIntOrNull()
            ?: throw IOException("Android did not return a numeric screen-off timeout.")

    override fun setScreenTimeoutMillis(timeoutMillis: Int) {
        val safe = timeoutMillis.coerceIn(60000, 3600000)
        runShell("/system/bin/settings put system screen_off_timeout " + safe)
        val actual = runShell("/system/bin/settings get system screen_off_timeout").toIntOrNull()
        if (actual != safe) {
            throw IOException("Screen timeout write was not retained by Android (requested $safe ms, read back ${actual ?: "unknown"} ms).")
        }
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

    private fun readVolumeState(stream: Int): VolumeState {
        val safeStream = validateStream(stream)
        val output = try {
            runShell("/system/bin/cmd media_session volume --stream " + safeStream + " --get")
        } catch (first: Exception) {
            try {
                runShell("/system/bin/media volume --stream " + safeStream + " --get")
            } catch (second: Exception) {
                throw IOException("Could not query Android volume (cmd media_session: ${first.message}; media: ${second.message})")
            }
        }
        val match = Regex(
            "volume is\\s*(-?\\d+)\\s+in range\\s*\\[(-?\\d+)\\.\\.(-?\\d+)\\]",
            RegexOption.IGNORE_CASE
        ).find(output)
        if (match != null) {
            val current = match.groupValues[1].toInt()
            val minimum = match.groupValues[2].toInt()
            val maximum = match.groupValues[3].toInt()
            return VolumeState(current, minimum, maximum)
        }
        throw IOException("Could not parse Android volume state: " + output.take(180))
    }

    private fun runShell(command: String): String {
        val process = ProcessBuilder("/system/bin/sh", "-c", command)
            .redirectErrorStream(true)
            .apply { environment()["PATH"] = "/system/bin:/system/xbin:/vendor/bin:/product/bin" }
            .start()
        val output = process.inputStream.bufferedReader().use { it.readText() }.trim()
        val exitCode = process.waitFor()
        if (exitCode != 0) {
            throw IOException("Command failed ($exitCode): " + output.take(220))
        }
        return output
    }
}
