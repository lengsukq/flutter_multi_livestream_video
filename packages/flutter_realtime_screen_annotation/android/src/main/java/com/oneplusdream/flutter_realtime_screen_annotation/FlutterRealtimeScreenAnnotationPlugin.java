package com.oneplusdream.flutter_realtime_screen_annotation;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.content.Intent;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.hardware.display.DisplayManager;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.widget.*;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.*;
import io.flutter.plugin.common.*;
import java.util.*;

/** System windows and gestures only. Room permissions and networking stay in Dart. */
public final class FlutterRealtimeScreenAnnotationPlugin implements FlutterPlugin,
        MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private static final int PERMISSION_REQUEST = 29461;
    private Context context;
    private ActivityPluginBinding activityBinding;
    private MethodChannel channel;
    private MethodChannel.Result permissionResult;
    private WindowManager manager;
    private InkView ink;
    private MovableBar bar;
    private TextView status;
    private Dialog labelDialog;
    private WindowManager.LayoutParams inkParams, barParams;
    private String session = "", tool = "pen";
    private boolean drawing, zh, failed;
    private int displayWidth, displayHeight, rotation;
    private float vx, vy, vw = 1, vh = 1;
    private List<Map<String,Object>> shapes = new ArrayList<>();
    private final Map<String,Map<String,Object>> drafts = new LinkedHashMap<>();
    private final List<Button> toolButtons = new ArrayList<>();
    private Map<String,Object> stroke;
    private long emittedAt;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final DisplayManager.DisplayListener displayListener = new DisplayManager.DisplayListener() {
        public void onDisplayAdded(int id) {}
        public void onDisplayRemoved(int id) { if (id == Display.DEFAULT_DISPLAY && ink != null) changedDisplay(); }
        public void onDisplayChanged(int id) {
            if (id == Display.DEFAULT_DISPLAY && ink != null) {
                Point size = new Point();
                manager.getDefaultDisplay().getRealSize(size);
                if (manager.getDefaultDisplay().getRotation() != rotation || size.x != displayWidth || size.y != displayHeight) {
                    changedDisplay();
                }
            }
        }
    };
    private void changedDisplay() { event("geometryChanged", null); close(); }

    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_realtime_screen_annotation");
        channel.setMethodCallHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        close(); cancelPermission(); channel.setMethodCallHandler(null); channel = null; context = null;
    }
    @Override public void onAttachedToActivity(ActivityPluginBinding binding) {
        activityBinding = binding; binding.addActivityResultListener(this);
    }
    private void detachActivity() {
        if (activityBinding != null) activityBinding.removeActivityResultListener(this);
        activityBinding = null;
    }
    @Override public void onDetachedFromActivityForConfigChanges() { detachActivity(); }
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) { onAttachedToActivity(binding); }
    @Override public void onDetachedFromActivity() { detachActivity(); cancelPermission(); close(); }
    private void cancelPermission() { if (permissionResult != null) { permissionResult.success(false); permissionResult = null; } }

    @Override public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != PERMISSION_REQUEST) return false;
        if (permissionResult != null) { permissionResult.success(Settings.canDrawOverlays(context)); permissionResult = null; }
        return true;
    }

    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "capabilities": result.success(map("supported", true, "permissionRequired", true)); break;
                case "cancel": cancelPermission(); result.success(null); break;
                case "requestPermission":
                    if (Settings.canDrawOverlays(context)) { result.success(true); break; }
                    if (permissionResult != null || activityBinding == null) {
                        result.error("overlay_permission", "Return to the app to allow drawing over other apps.", null);
                        break;
                    }
                    permissionResult = result;
                    try {
                        activityBinding.getActivity().startActivityForResult(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + context.getPackageName())), PERMISSION_REQUEST);
                    } catch (RuntimeException e) { permissionResult = null; throw e; }
                    break;
                case "open": open(call); result.success(null); break;
                case "update":
                    if (Objects.equals(session, call.argument("sessionId")) && ink != null) {
                        shapes = readShapes(call.argument("shapes")); failed = call.argument("error") != null;
                        if (status != null) {
                            status.setText(failed ? (zh ? "同步失败" : "Sync failed") : "⋮⋮");
                        }
                        if (failed) { drafts.clear(); stroke = null; setDrawing(false); }
                        updateButtonStates();
                        ink.invalidate();
                    }
                    result.success(null); break;
                case "ack":
                    if (Objects.equals(session, call.argument("sessionId"))) { drafts.remove(call.argument("id")); if (ink != null) ink.invalidate(); }
                    result.success(null); break;
                case "close": if (Objects.equals(session, call.argument("sessionId"))) close(); result.success(null); break;
                default: result.notImplemented();
            }
        } catch (RuntimeException e) { if (call.method.equals("open")) close(); result.error("system_annotation_failed", e.getMessage(), null); }
    }

    @SuppressWarnings("unchecked") private List<Map<String,Object>> readShapes(Object raw) {
        return raw instanceof List ? (List<Map<String,Object>>) raw : new ArrayList<>();
    }

    private void open(MethodCall call) {
        if (!Settings.canDrawOverlays(context)) throw new IllegalStateException("Drawing-over-apps permission is required.");
        close(); session = call.argument("sessionId"); zh = "zh".equals(call.argument("languageCode"));
        manager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
        Point size = new Point(); manager.getDefaultDisplay().getRealSize(size);
        displayWidth = size.x; displayHeight = size.y; rotation = manager.getDefaultDisplay().getRotation();
        Map<?,?> viewport = call.argument("viewport");
        vx = num(viewport.get("x")); vy = num(viewport.get("y")); vw = num(viewport.get("width")); vh = num(viewport.get("height"));
        shapes = readShapes(call.argument("shapes")); failed = false;
        int type = Build.VERSION.SDK_INT >= 26 ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_PHONE;
        inkParams = new WindowManager.LayoutParams((int)(vw*displayWidth), (int)(vh*displayHeight), type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE |
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT);
        inkParams.gravity = Gravity.TOP | Gravity.LEFT; inkParams.x=(int)(vx*displayWidth); inkParams.y=(int)(vy*displayHeight);
        inkParams.alpha = .7f;
        if (Build.VERSION.SDK_INT >= 28) inkParams.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        ink = new InkView(context); manager.addView(ink, inkParams);

        barParams = new WindowManager.LayoutParams(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT);
        barParams.gravity = Gravity.TOP | Gravity.LEFT;
        barParams.x = Math.max(dp(8), (displayWidth - dp(350)) / 2);
        barParams.y = dp(48);

        setupModernToolbar();
        drawing = false;
        updateButtonStates();
        ((DisplayManager)context.getSystemService(Context.DISPLAY_SERVICE)).registerDisplayListener(displayListener, main);
    }

    private void setupModernToolbar() {
        toolButtons.clear();
        bar = new MovableBar(context);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setPadding(dp(6), dp(3), dp(6), dp(3));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(Color.argb(235, 32, 37, 48));
        bg.setCornerRadius(dp(14));
        bg.setStroke(dp(1), Color.argb(45, 255, 255, 255));
        bar.setBackground(bg);

        status = new TextView(context);
        status.setText("⋮⋮");
        status.setTextColor(Color.argb(128, 255, 255, 255));
        status.setTextSize(13);
        status.setPadding(dp(4), dp(4), dp(4), dp(4));
        bar.addView(status);

        // 0: Navigate
        addModernButton(zh ? "操作" : "Move", () -> { finishStroke(); setDrawing(false); });
        addSeparator();

        // 1-5: Tools
        for (String t : new String[]{"pen", "highlight", "circle", "arrow", "text"}) {
            String label = new String[]{"画笔", "高亮", "圆形", "箭头", "文字"}[Arrays.asList("pen", "highlight", "circle", "arrow", "text").indexOf(t)];
            addModernButton(zh ? label : capitalize(t), () -> {
                if (failed) return; finishStroke(); tool = t; setDrawing(true);
            });
        }
        addSeparator();

        // 6-8: Actions
        addModernButton(zh ? "撤销" : "Undo", () -> { finishStroke(); event("undo", null); });
        addModernButton(zh ? "清除" : "Clear", () -> { finishStroke(); event("clear", null); });
        addModernButton(zh ? "关闭" : "Close", () -> { event("closed", null); close(); });
        manager.addView(bar, barParams);
    }

    private void addSeparator() {
        View sep = new View(context);
        sep.setBackgroundColor(Color.argb(40, 255, 255, 255));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dp(1), dp(18));
        lp.setMargins(dp(2), 0, dp(2), 0);
        bar.addView(sep, lp);
    }

    private static String capitalize(String s) {
        if (s == null || s.isEmpty()) return "";
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    private int dp(int n) { return (int)(n * context.getResources().getDisplayMetrics().density + .5f); }

    private void addModernButton(String label, Runnable action) {
        Button b = new Button(context);
        b.setText(label);
        b.setTextSize(11);
        b.setTextColor(Color.WHITE);
        b.setBackgroundColor(Color.TRANSPARENT);
        b.setMinWidth(0);
        b.setMinimumWidth(0);
        b.setMinHeight(0);
        b.setMinimumHeight(0);
        b.setPadding(dp(6), dp(4), dp(6), dp(4));
        bar.addView(b, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(36)));
        b.setOnClickListener(v -> action.run());
        toolButtons.add(b);
    }

    private void updateButtonStates() {
        if (toolButtons.isEmpty()) return;
        for (int i = 0; i < toolButtons.size(); i++) {
            Button b = toolButtons.get(i);
            boolean selected = false;
            if (i == 0) {
                selected = !drawing;
            } else if (i <= 5 && drawing) {
                String[] tNames = {"pen", "highlight", "circle", "arrow", "text"};
                selected = tool.equals(tNames[i - 1]);
            }
            if (selected) {
                GradientDrawable selBg = new GradientDrawable();
                selBg.setColor(Color.argb(90, 245, 158, 11));
                selBg.setCornerRadius(dp(8));
                b.setBackground(selBg);
                b.setTextColor(Color.rgb(255, 213, 79));
            } else {
                b.setBackgroundColor(Color.TRANSPARENT);
                b.setTextColor(Color.WHITE);
            }
        }
    }

    private void setDrawing(boolean value) {
        drawing = value;
        if (ink == null) return;
        if (value) inkParams.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        else inkParams.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        manager.updateViewLayout(ink, inkParams);
        updateButtonStates();
    }

    private void close() {
        if (labelDialog != null) { labelDialog.dismiss(); labelDialog = null; }
        if (context != null) ((DisplayManager)context.getSystemService(Context.DISPLAY_SERVICE)).unregisterDisplayListener(displayListener);
        if (manager != null) {
            if (ink != null) { try { manager.removeViewImmediate(ink); } catch (RuntimeException ignored) {} }
            if (bar != null) { try { manager.removeViewImmediate(bar); } catch (RuntimeException ignored) {} }
        }
        ink = null; bar = null; stroke = null; drafts.clear(); shapes.clear(); toolButtons.clear(); drawing = false; session = "";
    }

    private static float num(Object v) { return ((Number)v).floatValue(); }
    private static Map<String,Object> map(Object... args) {
        Map<String,Object> r = new HashMap<>();
        for (int i = 0; i < args.length; i += 2) r.put((String)args[i], args[i+1]);
        return r;
    }
    private void event(String type, Map<String,Object> extra) {
        if (channel == null || session.isEmpty()) return;
        Map<String,Object> event = map("type", type, "sessionId", session);
        if (extra != null) event.putAll(extra);
        channel.invokeMethod("event", event);
    }
    @SuppressWarnings("unchecked") private List<Map<String,Object>> points(Map<String,Object> s) { return (List<Map<String,Object>>)s.get("points"); }
    private Map<String,Object> point(float rawX, float rawY) {
        return map("x", (double)Math.max(0, Math.min(1, (rawX / displayWidth - vx) / vw)),
                   "y", (double)Math.max(0, Math.min(1, (rawY / displayHeight - vy) / vh)));
    }
    private void beginStroke(float x, float y) {
        if (drafts.size() >= 8) return;
        stroke = map("id", UUID.randomUUID().toString(), "tool", tool, "color", tool.equals("highlight") ? 0xffffeb3bL : 0xfff59e0bL,
            "width", tool.equals("highlight") ? 16 : 3, "text", "", "points", new ArrayList<Map<String,Object>>());
        points(stroke).add(point(x, y));
        drafts.put((String)stroke.get("id"), stroke);
        emittedAt = 0;
        if (!tool.equals("text")) emitStroke(false);
    }
    private void emitStroke(boolean finished) {
        if (stroke == null) return;
        Map<String,Object> copy = new HashMap<>(stroke);
        copy.put("points", new ArrayList<>(points(stroke)));
        event("stroke", map("shape", copy, "finished", finished));
        emittedAt = SystemClock.uptimeMillis();
    }
    private void finishStroke() { if (stroke != null) { if (!"text".equals(stroke.get("tool"))) emitStroke(true); stroke = null; } }
    private void addLabel(float x, float y) {
        beginStroke(x, y); if (stroke == null) return;
        final Map<String,Object> label = stroke; stroke = null;
        labelDialog = new Dialog(context, android.R.style.Theme_Material_Light_Dialog_Alert);
        labelDialog.getWindow().setType(Build.VERSION.SDK_INT >= 26 ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_PHONE);
        LinearLayout content = new LinearLayout(context);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(16), dp(16), dp(16), dp(16));
        content.setBackgroundColor(Color.WHITE);
        EditText input = new EditText(context);
        input.setHint(zh ? "文字说明" : "Label");
        input.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(200)});
        content.addView(input);
        Button save = new Button(context);
        save.setText(zh ? "添加" : "Add");
        content.addView(save);
        save.setOnClickListener(v -> {
            String text = input.getText().toString().trim();
            if (text.isEmpty()) return;
            label.put("text", text);
            stroke = label;
            emitStroke(true);
            stroke = null;
            labelDialog.dismiss();
        });
        labelDialog.setOnDismissListener(d -> {
            if (((String)label.get("text")).isEmpty()) drafts.remove(label.get("id"));
            if (ink != null) ink.invalidate();
        });
        labelDialog.setContentView(content);
        labelDialog.show();
        input.requestFocus();
    }

    /** Intercept an actual drag without consuming ordinary tool-button taps. */
    private final class MovableBar extends LinearLayout {
        private float startX, startY;
        private int startBarX, startBarY;
        private boolean moving;
        MovableBar(Context c) { super(c); }
        @Override public boolean onInterceptTouchEvent(MotionEvent e) {
            if (e.getAction() == MotionEvent.ACTION_DOWN) {
                startX = e.getRawX();
                startY = e.getRawY();
                startBarX = barParams.x;
                startBarY = barParams.y;
                moving = false;
            } else if (e.getAction() == MotionEvent.ACTION_MOVE &&
                    Math.hypot(e.getRawX() - startX, e.getRawY() - startY) > ViewConfiguration.get(context).getScaledTouchSlop()) {
                moving = true;
            }
            return moving;
        }
        @Override public boolean onTouchEvent(MotionEvent e) {
            if (e.getAction() == MotionEvent.ACTION_MOVE) {
                barParams.x = Math.max(0, Math.min(displayWidth - getWidth(), startBarX + (int)(e.getRawX() - startX)));
                barParams.y = Math.max(0, Math.min(displayHeight - getHeight(), startBarY + (int)(e.getRawY() - startY)));
                manager.updateViewLayout(this, barParams);
            } else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) {
                moving = false;
            }
            return true;
        }
    }

    private final class InkView extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        InkView(Context c) { super(c); setBackgroundColor(Color.TRANSPARENT); }
        @Override public boolean onTouchEvent(MotionEvent e) {
            if (!drawing || failed) return false;
            if (e.getAction() == MotionEvent.ACTION_DOWN) {
                if (tool.equals("text")) addLabel(e.getRawX(), e.getRawY());
                else beginStroke(e.getRawX(), e.getRawY());
            } else if (e.getAction() == MotionEvent.ACTION_MOVE && stroke != null && points(stroke).size() < 2048) {
                List<Map<String,Object>> ps = points(stroke);
                if (tool.equals("pen") || tool.equals("highlight")) ps.add(point(e.getRawX(), e.getRawY()));
                else { while (ps.size() > 1) ps.remove(ps.size() - 1); ps.add(point(e.getRawX(), e.getRawY())); }
                if (SystemClock.uptimeMillis() - emittedAt >= 100) emitStroke(false);
            } else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) {
                finishStroke();
            }
            invalidate();
            return true;
        }
        @Override protected void onDraw(Canvas canvas) {
            int[] location = new int[2];
            getLocationOnScreen(location);
            canvas.save();
            canvas.translate(vx * displayWidth - location[0], vy * displayHeight - location[1]);
            float w = vw * displayWidth, h = vh * displayHeight;
            canvas.clipRect(0, 0, w, h);
            for (Map<String,Object> s : shapes) if (!drafts.containsKey(s.get("id"))) drawShape(canvas, s, w, h);
            for (Map<String,Object> s : drafts.values()) drawShape(canvas, s, w, h);
            canvas.restore();
        }
        private void drawShape(Canvas c, Map<String,Object> s, float w, float h) {
            List<Map<String,Object>> ps = points(s);
            if (ps.isEmpty()) return;
            String t = (String)s.get("tool");
            float scale = Math.min(w, h) / 720f;
            paint.setColor(((Number)s.get("color")).intValue());
            paint.setAlpha(t.equals("highlight") ? 89 : 255);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(Math.max(1, num(s.get("width")) * scale));
            paint.setStrokeCap(Paint.Cap.ROUND);
            paint.setStrokeJoin(Paint.Join.ROUND);
            float x = num(ps.get(0).get("x")) * w, y = num(ps.get(0).get("y")) * h;
            float ex = num(ps.get(ps.size() - 1).get("x")) * w, ey = num(ps.get(ps.size() - 1).get("y")) * h;
            if (t.equals("circle")) {
                c.drawOval(Math.min(x, ex), Math.min(y, ey), Math.max(x, ex), Math.max(y, ey), paint);
            } else if (t.equals("text")) {
                paint.setStyle(Paint.Style.FILL);
                paint.setTextSize(Math.max(10, 22 * scale));
                c.drawText((String)s.get("text"), x, y - paint.ascent(), paint);
            } else if (t.equals("arrow")) {
                c.drawLine(x, y, ex, ey, paint);
                double a = Math.atan2(ey - y, ex - x);
                float len = Math.max(8, 18 * scale);
                for (double d : new double[]{-.5, .5}) {
                    c.drawLine(ex, ey, ex - (float)Math.cos(a + d) * len, ey - (float)Math.sin(a + d) * len, paint);
                }
            } else {
                Path p = new Path();
                p.moveTo(x, y);
                for (int i = 1; i < ps.size(); i++) p.lineTo(num(ps.get(i).get("x")) * w, num(ps.get(i).get("y")) * h);
                if (ps.size() == 1) {
                    paint.setStyle(Paint.Style.FILL);
                    c.drawCircle(x, y, paint.getStrokeWidth() / 2, paint);
                } else {
                    c.drawPath(p, paint);
                }
            }
        }
    }
}
