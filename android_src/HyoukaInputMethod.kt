package com.hyouka.hyouka_tv_control

import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection

/**
 * Hidden input method used by the phone companion. Text is composed into the
 * currently focused TV editor while the user types on the phone.
 */
class HyoukaInputMethod : InputMethodService() {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var hasActiveEditor = false

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
    }

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        hasActiveEditor = true
    }

    override fun onFinishInput() {
        hasActiveEditor = false
        super.onFinishInput()
    }

    override fun onEvaluateInputViewShown(): Boolean {
        super.onEvaluateInputViewShown()
        return false
    }

    override fun onCreateInputView(): View? = null

    override fun onDestroy() {
        if (activeInstance === this) activeInstance = null
        hasActiveEditor = false
        super.onDestroy()
    }

    companion object {
        @Volatile
        private var activeInstance: HyoukaInputMethod? = null

        fun setRemoteComposingText(text: String, callback: (Boolean) -> Unit) =
            postToInputConnection(callback) { connection -> connection.setComposingText(text, 1) }

        fun finishRemoteComposition(callback: (Boolean) -> Unit) =
            postToInputConnection(callback) { connection -> connection.finishComposingText() }

        private fun postToInputConnection(callback: (Boolean) -> Unit, operation: (InputConnection) -> Boolean) {
            val instance = activeInstance
            if (instance == null) {
                callback(false)
                return
            }
            instance.mainHandler.post {
                val accepted = try {
                    val connection = instance.currentInputConnection
                    if (!instance.hasActiveEditor || connection == null) false else operation(connection)
                } catch (_: Exception) {
                    false
                }
                callback(accepted)
            }
        }
    }
}
