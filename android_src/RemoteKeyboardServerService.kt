package com.hyouka.hyouka_tv_control

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * LAN-only paired phone keyboard endpoint. The six-digit code is generated
 * for each start and checked for every text submission.
 */
class RemoteKeyboardServerService : Service() {
    private data class FailedAttempts(var failures: Int = 0, var blockedUntil: Long = 0L)

    private val clients = Executors.newFixedThreadPool(4)
    private val attempts = ConcurrentHashMap<String, FailedAttempts>()
    @Volatile private var serverSocket: ServerSocket? = null
    @Volatile private var acceptThread: Thread? = null

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
                NotificationChannel(CHANNEL_ID, "Remote keyboard", NotificationManager.IMPORTANCE_LOW)
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
            .setContentTitle("Hyouka Remote Keyboard")
            .setContentText("Phone keyboard is available on your local network.")
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
        socket.bind(InetSocketAddress(PORT), 12)
        serverSocket = socket
        synchronized(this) {
            activePort = socket.localPort
            serverError = null
            serverRunning = true
        }

        acceptThread = Thread({
            while (!socket.isClosed) {
                try {
                    val client = socket.accept()
                    clients.execute { handleClient(client) }
                } catch (_: SocketException) {
                    break
                } catch (error: IOException) {
                    if (!socket.isClosed) {
                        synchronized(this) { serverError = error.message ?: "Network socket error." }
                    }
                }
            }
        }, "hyouka-remote-keyboard-accept").apply {
            isDaemon = true
            start()
        }
    }

    private fun handleClient(client: Socket) {
        client.use { socket ->
            try {
                socket.soTimeout = 6000
                val input = BufferedInputStream(socket.getInputStream())
                val requestLine = readHttpLine(input, 4096) ?: return
                val request = requestLine.split(' ')
                if (request.size < 2) {
                    respond(socket, 400, "Bad Request", "text/plain; charset=utf-8", "Invalid request.")
                    return
                }

                val headers = HashMap<String, String>()
                var headerBytes = 0
                while (true) {
                    val line = readHttpLine(input, 8192) ?: break
                    headerBytes += line.length
                    if (headerBytes > 16384) {
                        respond(socket, 431, "Request Header Fields Too Large", "text/plain; charset=utf-8", "Headers too large.")
                        return
                    }
                    if (line.isEmpty()) break
                    val colon = line.indexOf(':')
                    if (colon > 0) headers[line.substring(0, colon).trim().lowercase()] = line.substring(colon + 1).trim()
                }

                val method = request[0].uppercase()
                val path = request[1].substringBefore('?')
                if (method == "GET" && (path == "/" || path == "/index.html")) {
                    respond(socket, 200, "OK", "text/html; charset=utf-8", phonePage())
                    return
                }
                if (method != "POST" || path != "/send") {
                    respond(socket, 404, "Not Found", "text/plain; charset=utf-8", "Not found.")
                    return
                }

                val origin = headers["origin"]
                val host = headers["host"]
                if (origin != null && host != null && origin != "http://" + host) {
                    respond(socket, 403, "Forbidden", "application/json; charset=utf-8", jsonError("Origin not allowed."))
                    return
                }

                val length = headers["content-length"]?.toIntOrNull()
                if (length == null || length < 1 || length > MAX_BODY_BYTES) {
                    respond(socket, 413, "Payload Too Large", "application/json; charset=utf-8", jsonError("Text payload is too large."))
                    return
                }
                val body = ByteArray(length)
                var offset = 0
                while (offset < length) {
                    val count = input.read(body, offset, length - offset)
                    if (count < 0) {
                        respond(socket, 400, "Bad Request", "application/json; charset=utf-8", jsonError("Incomplete request body."))
                        return
                    }
                    offset += count
                }

                val payload = try {
                    JSONObject(String(body, StandardCharsets.UTF_8))
                } catch (_: Exception) {
                    respond(socket, 400, "Bad Request", "application/json; charset=utf-8", jsonError("Invalid JSON."))
                    return
                }

                val clientAddress = socket.inetAddress.hostAddress ?: "unknown"
                val pinResult = verifyPin(clientAddress, payload.optString("pin"))
                if (pinResult == 429) {
                    respond(socket, 429, "Too Many Requests", "application/json; charset=utf-8", jsonError("Too many incorrect codes. Wait one minute and try again."))
                    return
                }
                if (pinResult != 200) {
                    respond(socket, 401, "Unauthorized", "application/json; charset=utf-8", jsonError("Incorrect pairing code."))
                    return
                }

                val text = payload.optString("text")
                if (text.isEmpty() || text.length > MAX_TEXT_CHARS ||
                    text.any { it == '\u0000' || (it < ' ' && it !in listOf('\n', '\r', '\t')) }) {
                    respond(socket, 400, "Bad Request", "application/json; charset=utf-8", jsonError("Text must contain 1 to 2000 characters."))
                    return
                }

                val latch = CountDownLatch(1)
                var committed = false
                HyoukaInputMethod.commitRemoteText(text) {
                    committed = it
                    latch.countDown()
                }
                if (!latch.await(3, TimeUnit.SECONDS)) {
                    respond(socket, 503, "Service Unavailable", "application/json; charset=utf-8", jsonError("The TV input method did not respond."))
                    return
                }
                if (!committed) {
                    respond(socket, 409, "Conflict", "application/json; charset=utf-8", jsonError("No active text field. Focus a text box on the TV and try again."))
                    return
                }

                respond(socket, 200, "OK", "application/json; charset=utf-8", JSONObject().put("ok", true).put("message", "Text sent.").toString())
            } catch (_: Exception) {
                // A disconnected browser or malformed request should not stop the listener.
            }
        }
    }

    private fun verifyPin(address: String, supplied: String): Int {
        val expected = pairingCode ?: return 401
        val state = attempts.computeIfAbsent(address) { FailedAttempts() }
        synchronized(state) {
            val now = System.currentTimeMillis()
            if (now < state.blockedUntil) return 429
            val valid = MessageDigest.isEqual(
                supplied.toByteArray(StandardCharsets.UTF_8),
                expected.toByteArray(StandardCharsets.UTF_8)
            )
            if (valid) {
                attempts.remove(address)
                return 200
            }
            state.failures += 1
            if (state.failures >= MAX_PIN_FAILURES) {
                state.failures = 0
                state.blockedUntil = now + BLOCK_DURATION_MS
                return 429
            }
            return 401
        }
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

    private fun respond(socket: Socket, code: Int, reason: String, contentType: String, body: String) {
        val bytes = body.toByteArray(StandardCharsets.UTF_8)
        val securityHeaders = if (contentType.startsWith("text/html")) {
            "Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'\r\n" +
                "X-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\n"
        } else ""
        val header = "HTTP/1.1 " + code + " " + reason + "\r\n" +
            "Content-Type: " + contentType + "\r\n" +
            "Content-Length: " + bytes.size + "\r\n" +
            "Cache-Control: no-store\r\n" +
            "X-Content-Type-Options: nosniff\r\n" +
            securityHeaders +
            "Connection: close\r\n\r\n"
        socket.getOutputStream().apply {
            write(header.toByteArray(StandardCharsets.ISO_8859_1))
            write(bytes)
            flush()
        }
    }

    private fun jsonError(message: String): String = JSONObject().put("ok", false).put("error", message).toString()

    private fun phonePage(): String = """
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#10131b">
<title>Hyouka Remote Keyboard</title>
<style>
:root{color-scheme:dark;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;background:#10131b;color:#f4f5fa}
*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;padding:22px}
main{width:min(100%,560px);background:#1b202c;border:1px solid #343b4d;border-radius:24px;padding:24px;box-shadow:0 18px 60px #0006}
h1{font-size:1.5rem;margin:0 0 8px}p{color:#b9c1d3;line-height:1.5;margin:8px 0 20px}
label{display:block;font-size:.92rem;font-weight:650;margin:16px 0 8px}
input,textarea{width:100%;font:inherit;color:#fff;background:#111622;border:1px solid #424b60;border-radius:13px;padding:14px;outline:none}
input:focus,textarea:focus{border-color:#a9b9ff;box-shadow:0 0 0 3px #a9b9ff22}
textarea{min-height:150px;resize:vertical}
button{width:100%;border:0;border-radius:13px;padding:15px;margin-top:14px;font:inherit;font-weight:750;background:#c1ccff;color:#171b28}
button:disabled{opacity:.5}
#status{min-height:1.5em;margin-top:14px;font-size:.93rem;color:#d4dcff}
small{display:block;color:#929db3;margin-top:14px;line-height:1.5}
</style>
</head>
<body>
<main>
<h1>Hyouka Remote Keyboard</h1>
<p>Enter the pairing code shown on your TV. Keep a text field focused on the TV, then send text from here.</p>
<form id="pair">
<label for="pin">TV pairing code</label>
<input id="pin" inputmode="numeric" autocomplete="one-time-code" maxlength="6" pattern="[0-9]{6}" placeholder="6-digit code" required>
<label for="text">Text to send</label>
<textarea id="text" autocomplete="off" autocapitalize="sentences" placeholder="Type here using your phone keyboard" required></textarea>
<button id="send" type="submit">Send to TV</button>
</form>
<div id="status" role="status" aria-live="polite"></div>
<small>Both devices must stay on the same local network. Text is sent only after the pairing code is checked.</small>
</main>
<script>
const form=document.getElementById('pair');
const statusBox=document.getElementById('status');
const sendButton=document.getElementById('send');
form.addEventListener('submit',async event=>{
 event.preventDefault();
 const pin=document.getElementById('pin').value.trim();
 const field=document.getElementById('text');
 const text=field.value;
 if(!/^[0-9]{6}$/.test(pin)){statusBox.textContent='Enter the 6-digit code shown on the TV.';return;}
 if(!text){statusBox.textContent='Type some text first.';field.focus();return;}
 sendButton.disabled=true;
 statusBox.textContent='Sending…';
 try{
  const response=await fetch('/send',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pin,text})});
  const result=await response.json();
  if(!response.ok||!result.ok) throw new Error(result.error||'Could not send text.');
  statusBox.textContent='Sent to TV.';
  field.value='';
  field.focus();
 }catch(error){statusBox.textContent=error.message||'Connection failed. Check the TV address and Wi-Fi.';}
 finally{sendButton.disabled=false;}
});
</script>
</body>
</html>
""".trimIndent()

    override fun onDestroy() {
        val previousError = serverError
        synchronized(this) {
            serverRunning = false
            pairingCode = null
            serverError = previousError
            activePort = PORT
        }
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        clients.shutdownNow()
        attempts.clear()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "hyouka_remote_keyboard"
        private const val NOTIFICATION_ID = 7402
        private const val PORT = 8765
        private const val MAX_BODY_BYTES = 8192
        private const val MAX_TEXT_CHARS = 2000
        private const val MAX_PIN_FAILURES = 5
        private const val BLOCK_DURATION_MS = 60_000L

        @Volatile private var pairingCode: String? = null
        @Volatile private var serverRunning = false
        @Volatile private var serverError: String? = null
        @Volatile private var activePort = PORT

        @Synchronized
        fun clearSession() {
            pairingCode = null
            serverRunning = false
            serverError = null
            activePort = PORT
        }

        @Synchronized
        fun prepareSession() {
            if (pairingCode == null) {
                val value = SecureRandom().nextInt(1_000_000)
                pairingCode = value.toString().padStart(6, '0')
            }
            serverError = null
        }

        fun statusSnapshot(): Map<String, Any?> {
            val addresses = localIpv4Addresses()
            val port = activePort
            val url = addresses.firstOrNull()?.let { "http://" + it + ":" + port }
            return mapOf(
                "running" to serverRunning,
                "starting" to (pairingCode != null && !serverRunning && serverError == null),
                "url" to url,
                "addresses" to addresses,
                "port" to port,
                "pin" to pairingCode,
                "error" to serverError
            )
        }

        private fun localIpv4Addresses(): List<String> {
            return try {
                val interfaces = NetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
                    .filter { it.isUp && !it.isLoopback }
                    .sortedBy {
                        when {
                            it.name.startsWith("wlan", true) -> 0
                            it.name.startsWith("eth", true) -> 1
                            else -> 2
                        }
                    }
                interfaces.flatMap { network ->
                    network.inetAddresses.toList()
                        .filterIsInstance<Inet4Address>()
                        .filter { !it.isLoopbackAddress && it.isSiteLocalAddress }
                        .map { it.hostAddress ?: "" }
                }.filter { it.isNotBlank() }.distinct()
            } catch (_: Exception) {
                emptyList()
            }
        }
    }
}
