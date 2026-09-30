package com.oneplusdream.flutter_realtime_media_ivs;

import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLExt;
import android.opengl.EGLSurface;
import android.opengl.GLES20;
import com.amazonaws.ivs.broadcast.CustomImageSource;
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrame;
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrameHub;
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrameSink;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.function.Consumer;

/** Uploads the already processed RGBA pixels to IVS's native input surface. */
final class ProcessedIvsVideoSink implements ProcessedVideoFrameSink {
    private final String sourceId;
    final CustomImageSource source;
    private final Consumer<Throwable> onFailure;
    private EGLDisplay display = EGL14.EGL_NO_DISPLAY;
    private EGLContext context = EGL14.EGL_NO_CONTEXT;
    private EGLSurface surface = EGL14.EGL_NO_SURFACE;
    private int program;
    private int texture;
    private int width;
    private int height;
    private boolean disposed;
    private boolean failed;
    private final FloatBuffer vertices = floats(-1f,-1f, 1f,-1f, -1f,1f, 1f,1f);
    // CameraX's first row is the top row; an EGL surface's first row is the bottom.
    private final FloatBuffer texCoords = floats(0f,1f, 1f,1f, 0f,0f, 1f,0f);

    ProcessedIvsVideoSink(String sourceId, CustomImageSource source, Consumer<Throwable> onFailure) {
        this.sourceId = sourceId;
        this.source = source;
        this.onFailure = onFailure;
        source.rotateOnConfigurationChanges(false);
        ProcessedVideoFrameHub.INSTANCE.register(sourceId, this);
    }

    @Override public synchronized void onVideoFrame(ProcessedVideoFrame frame) {
        if (disposed || failed) return;
        try {
            if (width != frame.getWidth() || height != frame.getHeight()) {
                width = frame.getWidth(); height = frame.getHeight();
                source.setSize(width, height);
            }
            if (display == EGL14.EGL_NO_DISPLAY) initialize();
            require(EGL14.eglMakeCurrent(display, surface, surface, context), "eglMakeCurrent");
            GLES20.glViewport(0, 0, width, height);
            GLES20.glUseProgram(program);
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture);
            GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1);
            // The shared SDK output is tightly packed; do not send rows from a vendor camera.
            if (frame.getRowStride() != width * 4) throw new IllegalArgumentException("IVS requires tightly packed RGBA.");
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, width, height,
                    0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, frame.getRgba());
            int position = GLES20.glGetAttribLocation(program, "position");
            int coordinates = GLES20.glGetAttribLocation(program, "coordinates");
            GLES20.glEnableVertexAttribArray(position);
            GLES20.glEnableVertexAttribArray(coordinates);
            GLES20.glVertexAttribPointer(position, 2, GLES20.GL_FLOAT, false, 0, vertices);
            GLES20.glVertexAttribPointer(coordinates, 2, GLES20.GL_FLOAT, false, 0, texCoords);
            GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "image"), 0);
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4);
            int error = GLES20.glGetError();
            if (error != GLES20.GL_NO_ERROR) throw new IllegalStateException("IVS RGBA upload failed: " + error);
            require(EGLExt.eglPresentationTimeANDROID(display, surface, frame.getTimestampNs()), "eglPresentationTime");
            require(EGL14.eglSwapBuffers(display, surface), "eglSwapBuffers");
        } catch (Throwable error) {
            failed = true;
            onFailure.accept(error);
        } finally {
            // The control thread can then acquire the context to dispose it.
            if (display != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            }
        }
    }

    private void initialize() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        int[] version = new int[2];
        require(EGL14.eglInitialize(display, version, 0, version, 1), "eglInitialize");
        EGLConfig[] configs = new EGLConfig[1];
        int[] count = new int[1];
        require(EGL14.eglChooseConfig(display, new int[]{
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                EGL14.EGL_RED_SIZE,8, EGL14.EGL_GREEN_SIZE,8, EGL14.EGL_BLUE_SIZE,8,
                EGL14.EGL_ALPHA_SIZE,8, 0x3142,1, EGL14.EGL_NONE}, 0, configs, 0, 1, count, 0)
                && count[0] > 0, "eglChooseConfig");
        context = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT,
                new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION,2,EGL14.EGL_NONE}, 0);
        require(context != EGL14.EGL_NO_CONTEXT, "eglCreateContext");
        surface = EGL14.eglCreateWindowSurface(display, configs[0], source.getInputSurface(),
                new int[]{EGL14.EGL_NONE}, 0);
        require(surface != EGL14.EGL_NO_SURFACE, "eglCreateWindowSurface");
        require(EGL14.eglMakeCurrent(display, surface, surface, context), "eglMakeCurrent");
        int vertex = shader(GLES20.GL_VERTEX_SHADER,
                "attribute vec2 position; attribute vec2 coordinates; varying vec2 uv; void main(){gl_Position=vec4(position,0.0,1.0);uv=coordinates;}");
        int fragment = shader(GLES20.GL_FRAGMENT_SHADER,
                "precision mediump float; varying vec2 uv; uniform sampler2D image; void main(){gl_FragColor=texture2D(image,uv);}");
        program = GLES20.glCreateProgram();
        GLES20.glAttachShader(program, vertex); GLES20.glAttachShader(program, fragment);
        GLES20.glLinkProgram(program);
        int[] linked = new int[1]; GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linked, 0);
        GLES20.glDeleteShader(vertex); GLES20.glDeleteShader(fragment);
        require(linked[0] != 0, "glLinkProgram");
        int[] textures = new int[1]; GLES20.glGenTextures(1, textures, 0); texture = textures[0];
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
    }

    synchronized void dispose() {
        if (disposed) return;
        disposed = true;
        ProcessedVideoFrameHub.INSTANCE.unregister(sourceId, this);
        if (display != EGL14.EGL_NO_DISPLAY) {
            if (EGL14.eglMakeCurrent(display, surface, surface, context)) {
                if (texture != 0) GLES20.glDeleteTextures(1, new int[]{texture}, 0);
                if (program != 0) GLES20.glDeleteProgram(program);
            }
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface);
            if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context);
            EGL14.eglTerminate(display);
        }
        source.release();
    }

    private static int shader(int type, String code) {
        int shader = GLES20.glCreateShader(type);
        GLES20.glShaderSource(shader, code); GLES20.glCompileShader(shader);
        int[] compiled = new int[1]; GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0);
        if (compiled[0] == 0) {
            String error = GLES20.glGetShaderInfoLog(shader); GLES20.glDeleteShader(shader);
            throw new IllegalStateException(error);
        }
        return shader;
    }
    private static void require(boolean condition, String operation) {
        if (!condition) throw new IllegalStateException(operation + " failed: " + EGL14.eglGetError());
    }
    private static FloatBuffer floats(float... values) {
        FloatBuffer data = ByteBuffer.allocateDirect(values.length * 4).order(ByteOrder.nativeOrder()).asFloatBuffer();
        data.put(values).rewind(); return data;
    }
}
