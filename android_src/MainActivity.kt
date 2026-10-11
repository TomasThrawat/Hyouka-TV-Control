package com.hyouka.hyouka_tv_control

import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.IBinder
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.hyouka.tvcontrol.ITvControlService
import rikka.shizuku.Shizuku
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "hyouka.tvcontrol/system"
        private const val REQUEST_CODE = 7104
        private const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
    }

    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var bindingTimeout: Runnable? = null
    private var lastServiceFailure: String? = null
    private var remoteService: ITvControlService? = null
    private var isBinding = false
    private var serviceBindAttempted = false
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val pendingServiceCalls = mutableListOf<(ITvControlService?) -> Unit>()
    private lateinit var userServiceArgs: Shizuku.UserServiceArgs

    private val userServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            remoteService = service?.let { ITvControlService.Stub.asInterface(it) }
            lastServiceFailure = if (remoteService == null) "Shizuku connected but returned an empty TV control binder." else null
            clearBindingTimeout()
            isBinding = false
            val callbacks = pendingServiceCalls.toList()
            pendingServiceCalls.clear()
            callbacks.forEach { callback -> callback(remoteService) }
            if (remoteService != null) {
                pendingPermissionResult?.let { result ->
                    pendingPermissionResult = null
                    result.success(statusSnapshot())
                }
            }
        }
        override fun onServiceDisconnected(name: ComponentName?) {
            clearBindingTimeout()
            remoteService = null
            lastServiceFailure = "Shizuku disconnected the TV control service."
            isBinding = false
            val callbacks = pendingServiceCalls.toList()
            pendingServiceCalls.clear()
            callbacks.forEach { it(null) }
        }
    }

    private val permissionResultListener = Shizuku.OnRequestPermissionResultListener { code, grantResult ->
        if (code != REQUEST_CODE) return@OnRequestPermissionResultListener
        runOnUiThread {
            val pending = pendingPermissionResult
            if (grantResult != PackageManager.PERMISSION_GRANTED) {
                pendingPermissionResult = null
                pending?.success(statusSnapshot())
            } else if (pending != null) {
                ensureService { service ->
                    pendingPermissionResult = null
                    pending.success(statusSnapshot(service != null))
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        userServiceArgs = Shizuku.UserServiceArgs(
            ComponentName(packageName, TvControlUserService::class.java.name)
        ).daemon(false).processNameSuffix("tv-control").tag("hyouka-tv-control-service").debuggable(false).version(8)
        Shizuku.addRequestPermissionResultListener(permissionResultListener)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkStatus" -> result.success(statusSnapshot())
            "requestShizukuPermission" -> requestShizukuPermission(result)
            "readDashboard" -> callWithService(result) { service ->
                mapOf(
                    "brightness" to service.getBrightnessPercent(),
                    "mediaVolume" to service.getVolumePercent(3),
                    "systemVolume" to service.getVolumePercent(1),
                    "alarmVolume" to service.getVolumePercent(4),
                    "timeoutMs" to service.getScreenTimeoutMillis(),
                    "device" to service.getDeviceInfo()
                )
            }
            "setBrightness" -> callWithService(result) { service ->
                service.setBrightnessPercent((call.argument<Int>("value") ?: 50).coerceIn(1, 100))
                true
            }
            "setVolume" -> callWithService(result) { service ->
                val stream = call.argument<Int>("stream") ?: 3
                val value = (call.argument<Int>("value") ?: 40).coerceIn(0, 100)
                service.setVolumePercent(stream, value)
                true
            }
            "setScreenTimeout" -> callWithService(result) { service ->
                service.setScreenTimeoutMillis(call.argument<Int>("value") ?: 600000)
                true
            }
            "getPreferences" -> {
                val prefs = getSharedPreferences("tv_control_preferences", MODE_PRIVATE)
                result.success(mapOf(
                    "language" to prefs.getString("language", "en"),
                    "theme" to prefs.getString("theme", "pureBlack")
                ))
            }
            "savePreferences" -> {
                val values = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                getSharedPreferences("tv_control_preferences", MODE_PRIVATE).edit()
                    .putString("language", values["language"]?.toString() ?: "en")
                    .putString("theme", values["theme"]?.toString() ?: "pureBlack")
                    .apply()
                result.success(true)
            }
            "openShizuku" -> {
                val launch = packageManager.getLaunchIntentForPackage(SHIZUKU_PACKAGE)
                if (launch != null) {
                    startActivity(launch)
                    result.success(true)
                } else {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:" + SHIZUKU_PACKAGE)))
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun requestShizukuPermission(result: MethodChannel.Result) {
        if (!Shizuku.pingBinder()) {
            result.success(statusSnapshot())
            return
        }
        if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
            ensureService { service -> result.success(statusSnapshot(service != null)) }
            return
        }
        if (pendingPermissionResult != null) {
            result.error("PERMISSION_PENDING", "A Shizuku permission request is already pending.", null)
            return
        }
        pendingPermissionResult = result
        try {
            Shizuku.requestPermission(REQUEST_CODE)
        } catch (error: Exception) {
            pendingPermissionResult = null
            result.error("SHIZUKU_REQUEST_FAILED", error.message, null)
        }
    }

    private fun statusSnapshot(serviceConnected: Boolean = remoteService != null): Map<String, Any?> {
        val running = try { Shizuku.pingBinder() } catch (_: Exception) { false }
        val granted = try {
            running && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) { false }
        val uid = try { if (running) Shizuku.getUid() else -1 } catch (_: Exception) { -1 }
        return mapOf(
            "running" to running,
            "permissionGranted" to granted,
            "serviceConnected" to (serviceConnected && remoteService != null),
            "serviceFailure" to lastServiceFailure,
            "uid" to if (uid >= 0) uid.toString() else "—",
            "androidVersion" to android.os.Build.VERSION.RELEASE,
            "api" to android.os.Build.VERSION.SDK_INT,
            "model" to android.os.Build.MODEL
        )
    }

    private fun clearBindingTimeout() {
        bindingTimeout?.let(mainHandler::removeCallbacks)
        bindingTimeout = null
    }

    private fun ensureService(callback: (ITvControlService?) -> Unit) {
        remoteService?.let { callback(it); return }
        val running = try { Shizuku.pingBinder() } catch (_: Exception) { false }
        val granted = try {
            running && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) { false }
        if (!running) {
            lastServiceFailure = "Shizuku binder is not running."
            callback(null)
            return
        }
        if (!granted) {
            lastServiceFailure = "Shizuku permission is not granted to this app."
            callback(null)
            return
        }
        val serverVersion = try { Shizuku.getVersion() } catch (_: Exception) { -1 }
        if (serverVersion >= 0 && serverVersion < 10) {
            lastServiceFailure = "Shizuku server API $serverVersion does not support UserService; API 10 or newer is required."
            callback(null)
            return
        }
        lastServiceFailure = null
        pendingServiceCalls.add(callback)
        if (isBinding) return
        isBinding = true
        clearBindingTimeout()
        bindingTimeout = Runnable {
            if (isBinding && remoteService == null) {
                isBinding = false
                bindingTimeout = null
                val callbacks = pendingServiceCalls.toList()
                pendingServiceCalls.clear()
                val serverVersion = try { Shizuku.getVersion() } catch (_: Exception) { -1 }
                val uid = try { Shizuku.getUid() } catch (_: Exception) { -1 }
                try { Shizuku.unbindUserService(userServiceArgs, userServiceConnection, false) } catch (_: Exception) {}
                serviceBindAttempted = false
                lastServiceFailure = "Shizuku UserService did not connect within 40 seconds (server API $serverVersion, patch ${try { Shizuku.getServerPatchVersion() } catch (_: Exception) { -1 }}, UID $uid). Permission is granted, but the service did not attach. Check Shizuku service-start logs if this persists."
                callbacks.forEach { it(null) }
            }
        }.also { mainHandler.postDelayed(it, 40000L) }
        try {
            serviceBindAttempted = true
            Shizuku.bindUserService(userServiceArgs, userServiceConnection)
        } catch (error: Exception) {
            clearBindingTimeout()
            try { Shizuku.unbindUserService(userServiceArgs, userServiceConnection, false) } catch (_: Exception) {}
            serviceBindAttempted = false
            lastServiceFailure = "Could not bind Shizuku UserService (server ${try { Shizuku.getVersion() } catch (_: Exception) { -1 }}): ${error.message ?: error.javaClass.simpleName}"
            isBinding = false
            val callbacks = pendingServiceCalls.toList()
            pendingServiceCalls.clear()
            callbacks.forEach { it(null) }
        }
    }

    private fun callWithService(result: MethodChannel.Result, operation: (ITvControlService) -> Any?) {
        ensureService { service ->
            if (service == null) {
                val running = try { Shizuku.pingBinder() } catch (_: Exception) { false }
                val granted = try { running && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED } catch (_: Exception) { false }
                val code = when {
                    !running -> "SHIZUKU_NOT_RUNNING"
                    !granted -> "SHIZUKU_PERMISSION_DENIED"
                    else -> "SHIZUKU_SERVICE_NOT_CONNECTED"
                }
                val message = when {
                    !running -> "Shizuku binder is not running. Start or restart Shizuku."
                    !granted -> "Shizuku is running, but this app's Shizuku permission is not granted. Open Shizuku > Apps and enable Hyouka TV Control."
                    else -> lastServiceFailure ?: "Shizuku is running and permission is granted, but the TV control service did not connect. Restart Shizuku and reopen this app."
                }
                result.error(code, message, null)
                return@ensureService
            }
            ioExecutor.execute {
                try {
                    val value = operation(service)
                    runOnUiThread { result.success(value) }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error("TV_CONTROL_FAILED", error.message ?: error.javaClass.simpleName, null)
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        clearBindingTimeout()
        Shizuku.removeRequestPermissionResultListener(permissionResultListener)
        try {
            if (serviceBindAttempted) Shizuku.unbindUserService(userServiceArgs, userServiceConnection, true)
        } catch (_: Exception) {}
        ioExecutor.shutdownNow()
        super.onDestroy()
    }
}
