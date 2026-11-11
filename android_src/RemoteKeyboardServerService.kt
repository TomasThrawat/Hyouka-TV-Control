package com.hyouka.hyouka_tv_control

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.os.IBinder
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Local companion endpoint for the native phone remote UI.
 * A TV is paired once; the phone then keeps a per-device token for future use.
 */
class RemoteKeyboardServerService : Service() {
    private data class PairAttempts(var failures: Int = 0, var blockedUntil: Long = 0L)
    private val pinAttempts = java.util.concurrent.ConcurrentHashMap<String, PairAttempts>()
    private val clients = Executors.newFixedThreadPool(4)
    @Volatile private var serverSocket: ServerSocket? = null
    @Volatile private var acceptThread: Thread? = null
    private var nsdManager: NsdManager? = null
    private var registrationListener: NsdManager.RegistrationListener? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            startForegroundCompat()
            if (serverSocket == null || serverSocket?.isClosed == true) startServer()
        } catch (error: Exception) {
            synchronized(this) {
                serverError = error.message ?: error.javaClass.simpleName
                serverRunning = false
            }
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun startForegroundCompat() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Hyouka TV connection", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle("Hyouka TV")
            .setContentText("Ready for the Hyouka phone remote on your local network.")
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startServer() {
        prepareSession()
        val socket = ServerSocket()
        socket.reuseAddress = true
        socket.bind(InetSocketAddress(PORT), 16)
        serverSocket = socket
        synchronized(this) {
            activePort = socket.localPort
            serverError = null
            serverRunning = true
        }
        advertiseService(socket.localPort)

        acceptThread = Thread({
            while (!socket.isClosed) {
                try {
                    val client = socket.accept()
                    clients.execute { handleClient(client) }
                } catch (_: SocketException) {
                    break
                } catch (error: IOException) {
                    if (!socket.isClosed) {
                        synchronized(this) { serverError = error.message ?: "Local network socket error." }
                    }
                }
            }
        }, "hyouka-tv-remote-accept").apply {
            isDaemon = true
            start()
        }
    }

    private fun advertiseService(port: Int) {
        val manager = getSystemService(NSD_SERVICE) as NsdManager
        nsdManager = manager
        val info = NsdServiceInfo().apply {
            serviceName = SERVICE_NAME
            serviceType = SERVICE_TYPE
            this.port = port
            setAttribute("id", deviceId().toByteArray(StandardCharsets.UTF_8))
        }
        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(serviceInfo: NsdServiceInfo) {
                synchronized(this@RemoteKeyboardServerService) {
                    advertisedName = serviceInfo.serviceName
                    serverError = null
                }
            }

            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                synchronized(this@RemoteKeyboardServerService) {
                    serverError = "TV discovery registration failed ($errorCode)."
                }
            }

            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) {}
            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}
        }
        registrationListener = listener
        manager.registerService(info, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    private fun handleClient(client: Socket) {
        client.use { socket ->
            try {
                socket.soTimeout = 6000
                val input = BufferedInputStream(socket.getInputStream())
                val requestLine = readHttpLine(input, 4096) ?: return
                val request = requestLine.split(' ')
                if (request.size < 2) {
                    respond(socket, 400, errorJson("Invalid request."))
                    return
                }
                val headers = HashMap<String, String>()
                var headerBytes = 0
                while (true) {
                    val line = readHttpLine(input, 8192) ?: break
                    headerBytes += line.length
                    if (headerBytes > 16384) {
                        respond(socket, 431, errorJson("Headers too large."))
                        return
                    }
                    if (line.isEmpty()) break
                    val colon = line.indexOf(':')
                    if (colon > 0) headers[line.substring(0, colon).trim().lowercase()] = line.substring(colon + 1).trim()
                }

                val method = request[0].uppercase()
                val path = request[1].substringBefore('?')
                if (method == "GET" && path == "/health") {
                    respond(socket, 200, JSONObject()
                        .put("ok", true)
                        .put("deviceId", deviceId())
                        .put("name", tvDisplayName())
                        .toString())
                    return
                }
                if (method != "POST" || path !in setOf("/pair", "/compose", "/finish")) {
                    respond(socket, 404, errorJson("Not found."))
                    return
                }

                val length = headers["content-length"]?.toIntOrNull()
                if (length == null || length < 1 || length > MAX_BODY_BYTES) {
                    respond(socket, 413, errorJson("Request body is too large."))
                    return
                }
                val body = ByteArray(length)
                var offset = 0
                while (offset < length) {
                    val count = input.read(body, offset, length - offset)
                    if (count < 0) {
                        respond(socket, 400, errorJson("Incomplete request body."))
                        return
                    }
                    offset += count
                }
                val payload = try {
                    JSONObject(String(body, StandardCharsets.UTF_8))
                } catch (_: Exception) {
                    respond(socket, 400, errorJson("Invalid JSON."))
                    return
                }

                val clientAddress = socket.inetAddress
                if (!clientAddress.isSiteLocalAddress && !clientAddress.isLinkLocalAddress) {
                    respond(socket, 403, errorJson("Only devices on the local network can connect."))
                    return
                }

                when (path) {
                    "/pair" -> pairPhone(socket, payload)
                    "/compose" -> {
                        if (!isPaired(payload)) {
                            respond(socket, 401, errorJson("This phone is not paired with the TV."))
                            return
                        }
                        val text = payload.optString("text")
                        if (text.length > MAX_TEXT_CHARS || text.any { it == '\u0000' }) {
                            respond(socket, 400, errorJson("Text is too long or contains an invalid character."))
                            return
                        }
                        val accepted = awaitInput { callback -> HyoukaInputMethod.setRemoteComposingText(text, callback) }
                        if (!accepted) {
                            respond(socket, 409, errorJson("Open a text field on the TV and select Hyouka Remote Keyboard."))
                            return
                        }
                        respond(socket, 200, JSONObject().put("ok", true).toString())
                    }
                    "/finish" -> {
                        if (!isPaired(payload)) {
                            respond(socket, 401, errorJson("This phone is not paired with the TV."))
                            return
                        }
                        val accepted = awaitInput { callback -> HyoukaInputMethod.finishRemoteComposition(callback) }
                        if (!accepted) {
                            respond(socket, 409, errorJson("No active TV text field."))
                            return
                        }
                        respond(socket, 200, JSONObject().put("ok", true).toString())
                    }
                }
            } catch (_: Exception) {
                // A disconnected phone request must not stop the listener.
            }
        }
    }

    private fun pairPhone(socket: Socket, payload: JSONObject) {
        val suppliedPin = payload.optString("pin")
        val phoneId = payload.optString("deviceId")
        if (!phoneId.matches(Regex("[A-Za-z0-9-]{8,64}"))) {
            respond(socket, 400, errorJson("Invalid phone identifier."))
            return
        }
        val address = socket.inetAddress.hostAddress ?: "unknown"
        val expectedPin = pairingCode ?: ""
        val pairState = pinAttempts.computeIfAbsent(address) { PairAttempts() }
        synchronized(pairState) {
            val now = System.currentTimeMillis()
            if (now < pairState.blockedUntil) {
                respond(socket, 429, errorJson("Too many incorrect codes. Wait one minute and try again."))
                return
            }
            if (!constantTimeEquals(suppliedPin, expectedPin)) {
                pairState.failures += 1
                if (pairState.failures >= MAX_PAIR_FAILURES) {
                    pairState.failures = 0
                    pairState.blockedUntil = now + PAIR_BLOCK_MS
                }
                respond(socket, 401, errorJson("The pairing code is incorrect. Check the code shown on the TV."))
                return
            }
            pinAttempts.remove(address)
        }

        val token = randomToken()
        val preferences = getSharedPreferences(PREFS, MODE_PRIVATE)
        val pairs = try {
            JSONObject(preferences.getString(PAIRED_PHONES, "{}") ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        pairs.put(phoneId, token)
        preferences.edit().putString(PAIRED_PHONES, pairs.toString()).apply()

        respond(socket, 200, JSONObject()
            .put("ok", true)
            .put("token", token)
            .put("deviceId", deviceId())
            .put("name", tvDisplayName())
            .toString())
    }

    private fun isPaired(payload: JSONObject): Boolean {
        val phoneId = payload.optString("deviceId")
        val supplied = payload.optString("token")
        if (phoneId.isBlank() || supplied.isBlank()) return false
        val pairs = try {
            JSONObject(getSharedPreferences(PREFS, MODE_PRIVATE).getString(PAIRED_PHONES, "{}") ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        val expected = pairs.optString(phoneId)
        return expected.isNotBlank() && constantTimeEquals(supplied, expected)
    }

    private fun awaitInput(request: ((Boolean) -> Unit) -> Unit): Boolean {
        val latch = CountDownLatch(1)
        var accepted = false
        request {
            accepted = it
            latch.countDown()
        }
        return latch.await(3, TimeUnit.SECONDS) && accepted
    }

    private fun constantTimeEquals(first: String, second: String): Boolean =
        MessageDigest.isEqual(
            first.toByteArray(StandardCharsets.UTF_8),
            second.toByteArray(StandardCharsets.UTF_8)
        )

    private fun randomToken(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return android.util.Base64.encodeToString(
            bytes,
            android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING
        )
    }

    private fun readHttpLine(input: BufferedInputStream, maxBytes: Int): String? {
        val bytes = ByteArrayOutputStream()
        while (bytes.size() <= maxBytes) {
            val next = input.read()
            if (next == -1) return if (bytes.size() == 0) null else String(bytes.toByteArray(), StandardCharsets.ISO_8859_1)
            if (next == 10) break
            if (next != 13) bytes.write(next)
        }
        if (bytes.size() > maxBytes) throw IOException("HTTP line too long.")
        return String(bytes.toByteArray(), StandardCharsets.ISO_8859_1)
    }

    private fun respond(socket: Socket, code: Int, body: String) {
        val bytes = body.toByteArray(StandardCharsets.UTF_8)
        val reason = when (code) {
            200 -> "OK"
            400 -> "Bad Request"
            401 -> "Unauthorized"
            404 -> "Not Found"
            409 -> "Conflict"
            413 -> "Payload Too Large"
            431 -> "Request Header Fields Too Large"
            else -> "Service Unavailable"
        }
        val header = "HTTP/1.1 " + code + " " + reason + "\r\n" +
            "Content-Type: application/json; charset=utf-8\r\n" +
            "Content-Length: " + bytes.size + "\r\n" +
            "Cache-Control: no-store\r\n" +
            "X-Content-Type-Options: nosniff\r\n" +
            "Connection: close\r\n\r\n"
        socket.getOutputStream().apply {
            write(header.toByteArray(StandardCharsets.ISO_8859_1))
            write(bytes)
            flush()
        }
    }

    private fun errorJson(message: String): String =
        JSONObject().put("ok", false).put("error", message).toString()

    private fun deviceId(): String {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val existing = prefs.getString(TV_DEVICE_ID, null)
        if (!existing.isNullOrBlank()) return existing
        val created = UUID.randomUUID().toString()
        prefs.edit().putString(TV_DEVICE_ID, created).apply()
        return created
    }

    private fun tvDisplayName(): String =
        Build.MODEL?.takeIf { it.isNotBlank() }?.let { "Hyouka TV · $it" } ?: SERVICE_NAME

    override fun onDestroy() {
        try {
            registrationListener?.let { nsdManager?.unregisterService(it) }
        } catch (_: Exception) {}
        registrationListener = null
        nsdManager = null
        synchronized(this) {
            serverRunning = false
            pairingCode = null
            activePort = PORT
        }
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        clients.shutdownNow()
        pinAttempts.clear()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "hyouka_remote_keyboard"
        private const val NOTIFICATION_ID = 7402
        private const val PORT = 8765
        private const val SERVICE_NAME = "Hyouka TV"
        const val SERVICE_TYPE = "_hyouka-tv._tcp."
        private const val MAX_BODY_BYTES = 8192
        private const val MAX_TEXT_CHARS = 2000
        private const val MAX_PAIR_FAILURES = 5
        private const val PAIR_BLOCK_MS = 60_000L
        private const val PREFS = "hyouka_remote_keyboard"
        private const val TV_DEVICE_ID = "tv_device_id"
        private const val PAIRED_PHONES = "paired_phones"

        @Volatile private var pairingCode: String? = null
        @Volatile private var serverRunning = false
        @Volatile private var serverError: String? = null
        @Volatile private var activePort = PORT
        @Volatile private var advertisedName = SERVICE_NAME

        @Synchronized
        fun prepareSession() {
            if (pairingCode == null) {
                pairingCode = SecureRandom().nextInt(1_000_000).toString().padStart(6, '0')
            }
            serverError = null
        }

        fun statusSnapshot(): Map<String, Any?> = mapOf(
            "running" to serverRunning,
            "starting" to (pairingCode != null && !serverRunning && serverError == null),
            "pin" to pairingCode,
            "port" to activePort,
            "serviceName" to advertisedName,
            "error" to serverError
        )
    }
}
