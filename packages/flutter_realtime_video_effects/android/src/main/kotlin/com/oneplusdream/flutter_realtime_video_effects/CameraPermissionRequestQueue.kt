package com.oneplusdream.flutter_realtime_video_effects

/**
 * Coalesces concurrent camera-source requests into one Android permission prompt.
 *
 * Request codes change between prompts so a late callback from an Activity that
 * detached cannot accidentally complete requests made by its replacement.
 */
internal class CameraPermissionRequestQueue(
    initialRequestCode: Int = FIRST_REQUEST_CODE,
) {
    data class Failure(val code: String, val message: String)

    private data class PendingRequest(
        val onGranted: () -> Unit,
        val onDenied: (Failure) -> Unit,
    )

    private val pending = mutableListOf<PendingRequest>()
    private var nextRequestCode = initialRequestCode.coerceIn(FIRST_REQUEST_CODE, LAST_REQUEST_CODE)
    private var activeRequestCode: Int? = null

    internal val pendingCount: Int
        get() = pending.size

    internal val isRequestInFlight: Boolean
        get() = activeRequestCode != null

    fun request(
        hasPermission: Boolean,
        requestPermission: (requestCode: Int) -> Unit,
        onGranted: () -> Unit,
        onDenied: (Failure) -> Unit,
    ) {
        if (hasPermission) {
            onGranted()
            return
        }

        pending.add(PendingRequest(onGranted, onDenied))
        if (activeRequestCode != null) return

        val requestCode = allocateRequestCode()
        activeRequestCode = requestCode
        try {
            requestPermission(requestCode)
        } catch (error: Throwable) {
            complete(
                requestCode,
                Failure(
                    code = "permission_request_failed",
                    message = error.message ?: "Camera permission request could not be started.",
                ),
            )
        }
    }

    /** Returns true only when [requestCode] completes the currently active prompt. */
    fun onPermissionResult(requestCode: Int, granted: Boolean): Boolean {
        if (activeRequestCode != requestCode) return false
        val failure = if (granted) null else Failure(
            code = "permission_denied",
            message = "Camera permission was denied.",
        )
        complete(requestCode, failure)
        return true
    }

    /** Completes every waiting method call when its Activity or engine goes away. */
    fun cancelPending(message: String) {
        val requestCode = activeRequestCode ?: return
        complete(
            requestCode,
            Failure(code = "permission_request_cancelled", message = message),
        )
    }

    private fun complete(requestCode: Int, failure: Failure?) {
        if (activeRequestCode != requestCode) return
        activeRequestCode = null
        val requests = pending.toList()
        pending.clear()
        requests.forEach { request ->
            if (failure == null) request.onGranted() else request.onDenied(failure)
        }
    }

    private fun allocateRequestCode(): Int {
        val result = nextRequestCode
        nextRequestCode = if (nextRequestCode == LAST_REQUEST_CODE) {
            FIRST_REQUEST_CODE
        } else {
            nextRequestCode + 1
        }
        return result
    }

    private companion object {
        const val FIRST_REQUEST_CODE = 7000
        const val LAST_REQUEST_CODE = 0xFFFF
    }
}
