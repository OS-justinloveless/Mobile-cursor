package com.cursormobile.app.data

import android.content.Context
import android.content.SharedPreferences
import com.cursormobile.app.data.models.ChatMode
import com.cursormobile.app.data.models.ChatTool

/**
 * Manages persistent user preferences for new chat creation
 */
class ChatPreferencesManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE
    )

    companion object {
        private const val PREFS_NAME = "chat_preferences"
        private const val KEY_LAST_TOOL = "last_selected_tool"
        private const val KEY_LAST_MODE = "last_selected_mode"

        @Volatile
        private var instance: ChatPreferencesManager? = null

        fun getInstance(context: Context): ChatPreferencesManager {
            return instance ?: synchronized(this) {
                instance ?: ChatPreferencesManager(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    // MARK: - Save Preferences

    fun savePreferences(
        tool: ChatTool,
        mode: ChatMode
    ) {
        prefs.edit().apply {
            putString(KEY_LAST_TOOL, tool.value)
            putString(KEY_LAST_MODE, mode.value)
            apply()
        }
    }

    // MARK: - Load Preferences

    fun getLastTool(): ChatTool? {
        val value = prefs.getString(KEY_LAST_TOOL, null) ?: return null
        return ChatTool.entries.find { it.value == value }
    }

    fun getLastMode(): ChatMode? {
        val value = prefs.getString(KEY_LAST_MODE, null) ?: return null
        return ChatMode.entries.find { it.value == value }
    }

    // MARK: - Clear Preferences

    fun clearAllPreferences() {
        prefs.edit().apply {
            remove(KEY_LAST_TOOL)
            remove(KEY_LAST_MODE)
            apply()
        }
    }
}
