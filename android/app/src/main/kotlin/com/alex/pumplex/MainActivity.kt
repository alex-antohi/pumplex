package com.alex.pumplex

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "pumplex/files": save / open text files through Android's own file
 * screens (Storage Access Framework). No permissions, no plugins.
 */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var pendingContent: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pumplex/files")
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("busy", "Another file screen is already open", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "saveText" -> {
                        pending = result
                        pendingContent = call.argument<String>("content") ?: ""
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mime") ?: "text/plain"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "export.txt")
                        }
                        startActivityForResult(intent, SAVE_REQUEST)
                    }
                    "openText" -> {
                        pending = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startActivityForResult(intent, OPEN_REQUEST)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST && requestCode != OPEN_REQUEST) return
        val result = pending ?: return
        val content = pendingContent
        pending = null
        pendingContent = ""

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == SAVE_REQUEST) false else null)
            return
        }
        try {
            if (requestCode == SAVE_REQUEST) {
                val out = contentResolver.openOutputStream(uri, "w")
                    ?: throw java.io.IOException("Could not open the file for writing")
                out.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                result.success(true)
            } else {
                val input = contentResolver.openInputStream(uri)
                    ?: throw java.io.IOException("Could not open the file")
                result.success(input.use { it.readBytes().toString(Charsets.UTF_8) })
            }
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    companion object {
        private const val SAVE_REQUEST = 4201
        private const val OPEN_REQUEST = 4202
    }
}
