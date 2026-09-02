package com.example.money_manager

import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Telephony
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.example.money_manager/sms_reader"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "readInboxSms" -> {
                    val sinceTimestamp = (call.argument<Number>("sinceTimestamp"))?.toLong()
                    val limit = (call.argument<Int>("limit")) ?: 100
                    try {
                        val messages = readSmsInbox(sinceTimestamp, limit)
                        result.success(messages)
                    } catch (e: SecurityException) {
                        result.error("PERMISSION_DENIED", "SMS Permission denied: ${e.message}", null)
                    } catch (e: Exception) {
                        result.error("SMS_READ_ERROR", "Failed to read SMS: ${e.message}", null)
                    }
                }
                "checkSmsPermission" -> {
                    val granted = checkSelfPermission(android.Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun readSmsInbox(sinceTimestamp: Long?, limit: Int): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        val contentResolver = contentResolver
        val uri: Uri = Telephony.Sms.Inbox.CONTENT_URI

        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )

        var selection: String? = null
        var selectionArgs: Array<String>? = null

        if (sinceTimestamp != null && sinceTimestamp > 0) {
            selection = "${Telephony.Sms.DATE} > ?"
            selectionArgs = arrayOf(sinceTimestamp.toString())
        }

        val sortOrder = "${Telephony.Sms.DATE} DESC LIMIT $limit"

        val cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
        cursor?.use {
            val idIndex = it.getColumnIndex(Telephony.Sms._ID)
            val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)

            while (it.moveToNext()) {
                val id = if (idIndex != -1) it.getString(idIndex) else ""
                val address = if (addressIndex != -1) it.getString(addressIndex) ?: "" else ""
                val body = if (bodyIndex != -1) it.getString(bodyIndex) ?: "" else ""
                val date = if (dateIndex != -1) it.getLong(dateIndex) else 0L

                val map = HashMap<String, Any>()
                map["id"] = id
                map["address"] = address
                map["body"] = body
                map["date"] = date
                messages.add(map)
            }
        }

        return messages
    }
}
