# Agora Chat is backed by Hyphenate. Its AAR references optional OEM push
# integrations even when the application does not configure those push SDKs.
# They are not used by this provider-neutral demo, so R8 should not require
# their optional vendor classes.
-dontwarn com.heytap.msp.push.**
-dontwarn com.meizu.cloud.pushsdk.**
-dontwarn com.vivo.push.**
-dontwarn com.xiaomi.mipush.sdk.**
