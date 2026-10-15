package com.intelliattend.app.auth

import android.content.Context
import android.content.SharedPreferences
import android.provider.Settings
import dagger.hilt.android.qualifiers.ApplicationContext
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Global Interceptor for Anti-Spoofing Security Layer
 * Injects Authorization Bearer Token and Mandatory X-Device-ID header.
 */
@Singleton
class AuthInterceptor @Inject constructor(
    @ApplicationContext private val context: Context
) : Interceptor {

    private val prefs: SharedPreferences = context.getSharedPreferences(
        "IntelliAttendFaculty", 
        Context.MODE_PRIVATE
    )

    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        
        // Retrieve Token and Android ID
        val token = prefs.getString("access_token", null)
        val androidId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID
        ) ?: "unknown_device"

        val requestBuilder = originalRequest.newBuilder()
            .addHeader("X-Device-ID", androidId)
            .addHeader("Content-Type", "application/json")

        // Append Authorization header if token exists
        if (token != null && !originalRequest.header("Authorization").isNullOrEmpty().not()) {
            // Only add if not already present (e.g. for login/register where token might not exist yet)
            requestBuilder.header("Authorization", "Bearer $token")
        }

        return chain.proceed(requestBuilder.build())
    }
}
