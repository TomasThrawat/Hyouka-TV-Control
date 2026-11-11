package com.hyouka.hyouka_tv_control

import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.IBinder
import android.provider.Settings
import android.app.UiModeManager
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import android.view.inputmethod.InputMethodManager
import android.os.Build
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
        private const val PHONE_PREFS = "hyouka_phone_remote"
        private const val REMOTE_PORT = 8765
    }

    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var nsdDiscoveryListener: NsdManager.DiscoveryListener? = null
    private var discoveryTimeout: Runnable? = null
    private var discoveryResult: MethodChannel.Result? = null
    private val discoveredServices = ConcurrentHashMap<String, Map<String, Any>>()
    private var multicastLock: WifiManager.MulticastLock? = null
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
            "isTelevision" -> {
                val uiMode = getSystemService(UI_MODE_SERVICE) as UiModeManager
                result.success(uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION)
            }
            "ensureRemoteKeyboardServer", "startRemoteKeyboard" -> {
                try {
                    RemoteKeyboardServerService.prepareSession()
                    val intent = Intent(this, RemoteKeyboardServerService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                    result.success(remoteKeyboardStatus())
                } catch (error: Exception) {
                    result.error("REMOTE_KEYBOARD_START_FAILED", error.message ?: error.javaClass.simpleName, null)
                }
            }
            "stopRemoteKeyboard" -> {
                stopService(Intent(this, RemoteKeyboardServerService::class.java))
                result.success(remoteKeyboardStatus())
            }
            "remoteKeyboardStatus" -> result.success(remoteKeyboardStatus())
            "showKeyboardPicker" -> {
                (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager).showInputMethodPicker()
                result.success(true)
            }
            "discoverRemoteTvs" -> discoverRemoteTvs(result)
            "phoneRemoteStatus" -> result.success(phoneRemoteStatus())
            "pairRemoteTv" -> pairRemoteTv(call, result)
            "updateRemoteTvAddress" -> updateRemoteTvAddress(call, result)
            "sendRemoteComposition" -> sendPairedRequest("/compose", call, result)
            "finishRemoteComposition" -> sendPairedRequest("/finish", call, result)
            "forgetRemoteTv" -> {
                getSharedPreferences(PHONE_PREFS, MODE_PRIVATE).edit().clear().apply()
                result.success(true)
            }
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

    private fun phoneRemoteStatus(): Map<String, Any?> {
        val prefs = getSharedPreferences(PHONE_PREFS, MODE_PRIVATE)
        val token = prefs.getString("token", null)
        return mapOf(
            "paired" to !token.isNullOrBlank(),
            "host" to prefs.getString("host", ""),
            "port" to prefs.getInt("port", REMOTE_PORT),
            "tvId" to prefs.getString("tvId", ""),
            "name" to prefs.getString("name", "Hyouka TV")
        )
    }

    private fun phoneDeviceId(): String {
        val prefs = getSharedPreferences(PHONE_PREFS, MODE_PRIVATE)
        val existing = prefs.getString("phoneId", null)
        if (!existing.isNullOrBlank()) return existing
        val created = UUID.randomUUID().toString()
        prefs.edit().putString("phoneId", created).apply()
        return created
    }

    private fun pairRemoteTv(call: MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("host") ?: ""
        val port = call.argument<Int>("port") ?: REMOTE_PORT
        val pin = call.argument<String>("pin") ?: ""
        val tvId = call.argument<String>("tvId") ?: ""
        val name = call.argument<String>("name") ?: "Hyouka TV"
        if (host.isBlank() || pin.length != 6 || tvId.isBlank()) {
            result.error("INVALID_PAIRING_DATA", "Choose a TV and enter the six-digit code shown on it.", null)
            return
        }
        ioExecutor.execute {
            try {
                val phoneId = phoneDeviceId()
                val response = localRemoteRequest(host, port, "/pair", JSONObject()
                    .put("pin", pin)
                    .put("deviceId", phoneId))
                val token = response.getString("token")
                val actualTvId = response.optString("deviceId", tvId)
                val actualName = response.optString("name", name)
                getSharedPreferences(PHONE_PREFS, MODE_PRIVATE).edit()
                    .putString("phoneId", phoneId)
                    .putString("token", token)
                    .putString("host", host)
                    .putInt("port", port)
                    .putString("tvId", actualTvId)
                    .putString("name", actualName)
                    .apply()
                runOnUiThread { result.success(phoneRemoteStatus()) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("TV_PAIRING_FAILED", error.message ?: "Could not pair with this TV.", null)
                }
            }
        }
    }

    private fun updateRemoteTvAddress(call: MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("host") ?: ""
        val port = call.argument<Int>("port") ?: REMOTE_PORT
        val tvId = call.argument<String>("tvId") ?: ""
        val prefs = getSharedPreferences(PHONE_PREFS, MODE_PRIVATE)
        if (prefs.getString("tvId", null) != tvId || host.isBlank()) {
            result.success(false)
            return
        }
        prefs.edit().putString("host", host).putInt("port", port).apply()
        result.success(true)
    }

    private fun sendPairedRequest(path: String, call: MethodCall, result: MethodChannel.Result) {
        val prefs = getSharedPreferences(PHONE_PREFS, MODE_PRIVATE)
        val host = prefs.getString("host", null)
        val token = prefs.getString("token", null)
        val tvId = prefs.getString("tvId", null)
        val phoneId = prefs.getString("phoneId", null)
        val port = prefs.getInt("port", REMOTE_PORT)
        if (host.isNullOrBlank() || token.isNullOrBlank() || tvId.isNullOrBlank() || phoneId.isNullOrBlank()) {
            result.error("TV_NOT_PAIRED", "Pair the phone with your TV once first.", null)
            return
        }
        val payload = JSONObject()
            .put("deviceId", phoneId)
            .put("token", token)
        if (path == "/compose") {
            payload.put("text", call.argument<String>("text") ?: "")
        }
        ioExecutor.execute {
            try {
                localRemoteRequest(host, port, path, payload)
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("TV_TEXT_SEND_FAILED", error.message ?: "Could not send text to the TV.", null)
                }
            }
        }
    }

    private fun localRemoteRequest(host: String, port: Int, path: String, payload: JSONObject): JSONObject {
        val address = InetAddress.getByName(host)
        if (!address.isSiteLocalAddress && !address.isLinkLocalAddress) {
            throw IOException("The selected TV is not on a private local network.")
        }
        val formattedHost = if (host.contains(":")) "[$host]" else host
        val connection = URL("http://$formattedHost:$port$path").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 2500
            connection.readTimeout = 2500
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            val bytes = payload.toString().toByteArray(StandardCharsets.UTF_8)
            connection.setFixedLengthStreamingMode(bytes.size)
            connection.outputStream.use { it.write(bytes) }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() } ?: "{}"
            val response = try { JSONObject(body) } catch (_: Exception) { JSONObject() }
            if (code !in 200..299) {
                throw IOException(response.optString("error").ifBlank { "TV returned HTTP $code." })
            }
            return response
        } finally {
            connection.disconnect()
        }
    }

    private fun discoverRemoteTvs(result: MethodChannel.Result) {
        stopRemoteDiscovery()
        discoveredServices.clear()
        val manager = getSystemService(NSD_SERVICE) as NsdManager
        val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
        try {
            multicastLock = wifi.createMulticastLock("hyouka-tv-discovery").apply {
                setReferenceCounted(false)
                acquire()
            }
            val listener = object : NsdManager.DiscoveryListener {
                override fun onDiscoveryStarted(serviceType: String) {}

                override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                    if (serviceInfo.serviceType.trimEnd('.') != RemoteKeyboardServerService.SERVICE_TYPE.trimEnd('.')) return
                    try {
                        manager.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                            override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {}
                            override fun onServiceResolved(info: NsdServiceInfo) {
                                val host = info.host?.hostAddress ?: return
                                val deviceId = info.attributes["id"]?.let { String(it, StandardCharsets.UTF_8) } ?: return
                                discoveredServices[deviceId] = mapOf(
                                    "name" to info.serviceName,
                                    "host" to host,
                                    "port" to info.port,
                                    "tvId" to deviceId
                                )
                            }
                        })
                    } catch (_: Exception) {}
                }

                override fun onServiceLost(serviceInfo: NsdServiceInfo) {}
                override fun onDiscoveryStopped(serviceType: String) {}
                override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                    finishRemoteDiscovery(result, "TV discovery could not start ($errorCode).")
                }
                override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
            }
            nsdDiscoveryListener = listener
            discoveryResult = result
            manager.discoverServices(RemoteKeyboardServerService.SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
            discoveryTimeout = Runnable { finishRemoteDiscovery(result, null) }
                .also { mainHandler.postDelayed(it, 3000L) }
        } catch (error: Exception) {
            stopRemoteDiscovery()
            result.error("TV_DISCOVERY_FAILED", error.message ?: "Could not search for TVs.", null)
        }
    }

    private fun finishRemoteDiscovery(result: MethodChannel.Result, failure: String?) {
        if (discoveryResult !== result) return
        discoveryTimeout?.let(mainHandler::removeCallbacks)
        discoveryTimeout = null
        val listener = nsdDiscoveryListener
        nsdDiscoveryListener = null
        try {
            if (listener != null) (getSystemService(NSD_SERVICE) as NsdManager).stopServiceDiscovery(listener)
        } catch (_: Exception) {}
        multicastLock?.let { try { if (it.isHeld) it.release() } catch (_: Exception) {} }
        multicastLock = null
        discoveryResult = null
        if (failure != null) {
            result.error("TV_DISCOVERY_FAILED", failure, null)
        } else {
            result.success(discoveredServices.values.toList())
        }
    }

    private fun stopRemoteDiscovery() {
        discoveryTimeout?.let(mainHandler::removeCallbacks)
        discoveryTimeout = null
        val listener = nsdDiscoveryListener
        nsdDiscoveryListener = null
        try {
            if (listener != null) (getSystemService(NSD_SERVICE) as NsdManager).stopServiceDiscovery(listener)
        } catch (_: Exception) {}
        multicastLock?.let { try { if (it.isHeld) it.release() } catch (_: Exception) {} }
        multicastLock = null
        discoveryResult = null
    }

    private fun remoteKeyboardStatus(): Map<String, Any?> {
        val component = ComponentName(this, HyoukaInputMethod::class.java)
        val inputMethods = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        val enabled = inputMethods.enabledInputMethodList.any {
            it.packageName == packageName && it.serviceName == HyoukaInputMethod::class.java.name
        }
        val selectedId = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
        val selected = selectedId == component.flattenToString() || selectedId == component.flattenToShortString()
        return RemoteKeyboardServerService.statusSnapshot() + mapOf(
            "keyboardEnabled" to enabled,
            "keyboardSelected" to selected
        )
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
        stopRemoteDiscovery()
        clearBindingTimeout()
        Shizuku.removeRequestPermissionResultListener(permissionResultListener)
        try {
            if (serviceBindAttempted) Shizuku.unbindUserService(userServiceArgs, userServiceConnection, true)
        } catch (_: Exception) {}
        ioExecutor.shutdownNow()
        super.onDestroy()
    }
}
