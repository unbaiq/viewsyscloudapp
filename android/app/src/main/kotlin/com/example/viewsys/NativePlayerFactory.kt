package com.example.viewsys

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativePlayerFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    // Called by Flutter every time an AndroidView("native_video_player") widget is built
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        // args comes from Flutter's creationParams — cast safely
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<String, Any>
        return NativePlayerView(context, viewId, messenger, creationParams)
    }
}