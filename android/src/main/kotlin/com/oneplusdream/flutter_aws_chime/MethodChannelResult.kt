package com.oneplusdream.flutter_aws_chime

class MethodChannelResult(
        val result: Boolean,
        val arguments: Any?,
        val code: String? = null
) {
    fun toFlutterCompatibleType(): Map<String, Any?> {
        return mapOf(
                "success" to result,
                "code" to if (result) null else (code ?: "native_error"),
                "message" to if (result) null else arguments?.toString(),
                "data" to if (result) arguments else null,
                "details" to null
        )
    }
}
