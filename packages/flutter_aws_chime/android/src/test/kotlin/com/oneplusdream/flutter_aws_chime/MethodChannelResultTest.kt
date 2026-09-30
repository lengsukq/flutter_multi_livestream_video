package com.oneplusdream.flutter_aws_chime

import org.junit.Test
import kotlin.test.assertEquals

class MethodChannelResultTest {
    @Test
    fun successfulResponsesUseTheSharedPlatformChannelShape() {
        assertEquals(
                mapOf(
                        "success" to true,
                        "code" to null,
                        "message" to null,
                        "data" to listOf("Speaker", "Bluetooth"),
                        "details" to null
                ),
                MethodChannelResult(true, listOf("Speaker", "Bluetooth"))
                        .toFlutterCompatibleType()
        )
    }

    @Test
    fun failedResponsesIncludeStableCodeAndDescription() {
        assertEquals(
                mapOf(
                        "success" to false,
                        "code" to "permission_denied",
                        "message" to "Camera access denied.",
                        "data" to null,
                        "details" to null
                ),
                MethodChannelResult(
                        false,
                        "Camera access denied.",
                        "permission_denied"
                ).toFlutterCompatibleType()
        )
    }
}
