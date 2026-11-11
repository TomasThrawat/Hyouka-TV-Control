package com.hyouka.hyouka_tv_control

import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.inputmethod.EditorInfo

/**
 * Headless input method used only as a bridge for text committed from the
 * paired phone page. The focused TV editor remains the text target.
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

    // The phone supplies the keys, so do not cover the TV screen with another keyboard.
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

        fun commitRemoteText(text: String, callback: (Boolean) -> Unit) {
            val instance = activeInstance
            if (instance == null) {
                callback(false)
                return
            }

            instance.mainHandler.post {
                val committed = try {
                    if (!instance.hasActiveEditor) {
                        false
                    } else {
                        instance.currentInputConnection?.commitText(text, 1) == true
                    }
                } catch (_: Exception) {
                    false
                }
                callback(committed)
            }
        }
    }
}
