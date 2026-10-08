package com.oneplusdream.flutter_realtime_media_livekit;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import android.os.Bundle;
import android.os.ResultReceiver;

public final class ScreenShareForegroundService extends Service {
    static final String EXTRA_RESULT_RECEIVER = "screen_share_result_receiver";
    static final int RESULT_READY = 1;
    private static final String CHANNEL_ID =
            "flutter_realtime_media_livekit_screen_share";
    private static final int NOTIFICATION_ID = 21041;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        ResultReceiver receiver = intent == null ? null :
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                        ? intent.getParcelableExtra(EXTRA_RESULT_RECEIVER, ResultReceiver.class)
                        : intent.getParcelableExtra(EXTRA_RESULT_RECEIVER));
        try {
            Notification notification = buildNotification();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION);
            } else {
                startForeground(NOTIFICATION_ID, notification);
            }
            // Capturing is legal only after startForeground completes, not just
            // after Context.startForegroundService schedules this command.
            if (receiver != null) receiver.send(RESULT_READY, Bundle.EMPTY);
        } catch (RuntimeException error) {
            Bundle data = new Bundle();
            data.putString("message", error.getMessage());
            if (receiver != null) receiver.send(0, data);
            stopSelf(startId);
        }
        return START_NOT_STICKY;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Screen sharing",
                NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("Shows while your screen is being shared.");
        NotificationManager manager = getSystemService(NotificationManager.class);
        manager.createNotificationChannel(channel);
    }

    private Notification buildNotification() {
        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);
        return builder
                .setContentTitle("Screen sharing")
                .setContentText("Your screen is being shared.")
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
