package com.oneplusdream.flutter_realtime_video_effects

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class CameraPermissionRequestQueueTest {
    @Test fun concurrentSourceRequestsShareOnePermissionPromptAndAllResumeOnGrant() {
        val queue = CameraPermissionRequestQueue()
        val requestCodes = mutableListOf<Int>()
        val createdSources = mutableListOf<Int>()
        val errors = mutableListOf<CameraPermissionRequestQueue.Failure>()

        repeat(3) { index ->
            queue.request(
                hasPermission = false,
                requestPermission = { requestCodes.add(it) },
                onGranted = { createdSources.add(index) },
                onDenied = { errors.add(it) },
            )
        }

        assertEquals(1, requestCodes.size)
        assertEquals(3, queue.pendingCount)
        assertTrue(queue.isRequestInFlight)
        assertTrue(queue.onPermissionResult(requestCodes.single(), granted = true))
        assertEquals(listOf(0, 1, 2), createdSources)
        assertTrue(errors.isEmpty())
        assertEquals(0, queue.pendingCount)
        assertFalse(queue.isRequestInFlight)
    }

    @Test fun denialReturnsStablePermissionDeniedCodeForEveryWaitingCall() {
        val queue = CameraPermissionRequestQueue()
        var requestCode = -1
        val errors = mutableListOf<CameraPermissionRequestQueue.Failure>()

        repeat(2) {
            queue.request(
                hasPermission = false,
                requestPermission = { requestCode = it },
                onGranted = { error("Denied requests must not create a source.") },
                onDenied = { errors.add(it) },
            )
        }

        assertTrue(queue.onPermissionResult(requestCode, granted = false))
        assertEquals(2, errors.size)
        assertTrue(errors.all { it.code == "permission_denied" })
        assertTrue(errors.all { it.message == "Camera permission was denied." })
        assertEquals(0, queue.pendingCount)
    }

    @Test fun activityDetachCancelsPendingCallsAndLateOldResultCannotCompleteNewRequest() {
        val queue = CameraPermissionRequestQueue()
        val requestCodes = mutableListOf<Int>()
        val errors = mutableListOf<CameraPermissionRequestQueue.Failure>()
        var granted = 0

        fun request() = queue.request(
            hasPermission = false,
            requestPermission = { requestCodes.add(it) },
            onGranted = { granted++ },
            onDenied = { errors.add(it) },
        )

        request()
        val oldRequestCode = requestCodes.single()
        queue.cancelPending("Activity detached.")
        assertEquals(1, errors.size)
        assertEquals("permission_request_cancelled", errors.single().code)
        assertEquals(0, queue.pendingCount)
        assertFalse(queue.isRequestInFlight)

        request()
        val newRequestCode = requestCodes.last()
        assertTrue(newRequestCode != oldRequestCode)
        assertFalse(queue.onPermissionResult(oldRequestCode, granted = true))
        assertEquals(0, granted)
        assertEquals(1, queue.pendingCount)
        assertTrue(queue.onPermissionResult(newRequestCode, granted = true))
        assertEquals(1, granted)
        assertEquals(1, errors.size)
    }

    @Test fun permissionRequestFailureCompletesWaitersAndAllowsRetry() {
        val queue = CameraPermissionRequestQueue()
        var successfulRequestCode: Int? = null
        val errors = mutableListOf<CameraPermissionRequestQueue.Failure>()
        var granted = 0

        queue.request(
            hasPermission = false,
            requestPermission = { error("request failed") },
            onGranted = { granted++ },
            onDenied = { errors.add(it) },
        )
        assertEquals("permission_request_failed", errors.single().code)
        assertFalse(queue.isRequestInFlight)

        queue.request(
            hasPermission = false,
            requestPermission = { successfulRequestCode = it },
            onGranted = { granted++ },
            onDenied = { errors.add(it) },
        )
        assertTrue(queue.isRequestInFlight)
        assertTrue(queue.onPermissionResult(requireNotNull(successfulRequestCode), granted = true))
        assertEquals(1, granted)
        assertEquals(1, errors.size)
    }

    @Test fun alreadyGrantedPermissionSkipsThePromptAndStartsImmediately() {
        val queue = CameraPermissionRequestQueue()
        var promptCalls = 0
        var started = 0
        var failure: CameraPermissionRequestQueue.Failure? = null

        queue.request(
            hasPermission = true,
            requestPermission = { promptCalls++ },
            onGranted = { started++ },
            onDenied = { failure = it },
        )

        assertEquals(0, promptCalls)
        assertEquals(1, started)
        assertNull(failure)
        assertEquals(0, queue.pendingCount)
    }
}
