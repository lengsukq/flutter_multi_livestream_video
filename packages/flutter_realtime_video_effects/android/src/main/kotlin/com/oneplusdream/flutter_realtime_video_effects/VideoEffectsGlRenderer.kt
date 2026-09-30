package com.oneplusdream.flutter_realtime_video_effects

import android.graphics.Bitmap
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.cos
import kotlin.math.sin

/**
 * Offscreen GPU blur/compositing. The Flutter preview remains owned by Canvas
 * for its entire lifetime, so selecting an effect never changes its producer.
 * Created, rendered and released on the camera analyzer's single thread.
 */
internal class VideoEffectsGlRenderer {

    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var surface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var ready = false

    private var blitProgram = 0
    private var compositeProgram = 0
    private var blurProgram = 0

    private var foregroundTexture = 0
    private var backgroundTexture = 0
    private var replacementTexture = 0
    private var maskTexture = 0
    private var outputTexture = 0
    private var blurTexture = 0
    private var framebuffer = 0

    private var frameWidth = 0
    private var frameHeight = 0
    private var blurWidth = 0
    private var blurHeight = 0
    private var maskWidth = 0
    private var maskHeight = 0

    private var readback: ByteBuffer? = null
    private var flipped: ByteBuffer? = null
    private var rowScratch: ByteBuffer? = null

    /**
     * Identity of the backdrop already uploaded, so a still image is not
     * re-uploaded on every frame. Reset when the textures are reallocated.
     */
    private var backdropIdentity = 0
    private var backdropWidth = 0
    private var backdropHeight = 0

    private val vertices: FloatBuffer = floatBufferOf(
        // x, y, u, v. The top-left vertex is (-1, 1) so that texture row 0
        // (the top row of a camera frame) lands at the top of the viewport;
        // GL's texture origin is bottom-left, unlike a camera buffer.
        -1f, 1f, 0f, 0f,
        1f, 1f, 1f, 0f,
        -1f, -1f, 0f, 1f,
        1f, -1f, 1f, 1f,
    )

    /** Tightly packed, top-down RGBA output. */
    class Frame(
        val pixels: ByteBuffer,
        val width: Int,
        val height: Int,
    )

    /**
     * Renders one camera frame.
     *
     * @param frame tightly packed RGBA, or a padded buffer when [rowStride]
     *   differs from `width * 4`.
     * @param mask RGBA where the alpha channel carries the person matte, or
     *   null to show the frame untouched.
     * @param backdrop the replacement image for `replaceImage`.
     */
    fun render(
        frame: ByteBuffer,
        frameWidth: Int,
        frameHeight: Int,
        rowStride: Int,
        mask: ByteBuffer?,
        maskWidth: Int,
        maskHeight: Int,
        backdrop: Bitmap?,
        effectType: String,
        rotationDegrees: Int,
        mirrored: Boolean,
        blurDivisor: Int,
    ): Frame {
        require(frameWidth > 0 && frameHeight > 0)
        ensureReady()
        val blurScale = 4
        resizeIfNeeded(frameWidth, frameHeight, maskWidth, maskHeight, blurScale)

        // 1. Camera frame straight into a texture. No Bitmap is ever built.
        uploadTexture(foregroundTexture, frame, frameWidth, frameHeight, rowStride)

        // Replacement images have their own texture. Uploading them into the
        // blur target used to change its storage dimensions and crop uniforms;
        // switching back to blur then rendered a shrunken/offset camera frame.
        if (effectType == "replaceImage" && backdrop != null && !backdrop.isRecycled) {
            if (backdropIdentity != backdropIdentityFor(backdrop)) uploadBackdrop(backdrop)
        } else if (effectType == "blur") {
            val radius = blurDivisor.toFloat()
            drawBlur(blurTexture, foregroundTexture, radius / frameWidth, 0f)
            drawBlur(backgroundTexture, blurTexture, 0f, radius / frameHeight)
        }

        val composeWithMatte = effectType != "none" && mask != null
        if (composeWithMatte) {
            uploadMask(mask, maskWidth, maskHeight)
            drawComposite(effectType, mirrored, rotationDegrees)
        } else {
            drawBlit(outputTexture, foregroundTexture, if (mirrored) 1f else 0f)
        }

        val byteCount = frameWidth * frameHeight * 4
        val target = readback?.takeIf { it.capacity() >= byteCount } ?: ByteBuffer
            .allocateDirect(byteCount)
            .order(ByteOrder.nativeOrder())
            .also { readback = it }
        target.clear()
        target.limit(byteCount)
        GLES20.glReadPixels(
            0, 0, frameWidth, frameHeight,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, target,
        )
        // JNI does not advance position. flip() would make the limit zero.
        target.position(0)
        check(GLES20.glGetError() == GLES20.GL_NO_ERROR) {
            "Could not read the processed camera frame."
        }
        val pixels = RgbaReadback.topDown(target, frameWidth, frameHeight, flipped)
        flipped = pixels
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        return Frame(pixels, frameWidth, frameHeight)
    }

    private fun backdropIdentityFor(backdrop: Bitmap): Int =
        System.identityHashCode(backdrop)

    /**
     * Draws [source] into [target] through the offscreen framebuffer. Both the
     * blur passes and the final composite go through here, so the target is
     * attached to the FBO rather than assumed.
     */
    private fun drawBlit(target: Int, source: Int, mirror: Float) {
        val texWidth = if (target == blurTexture) blurWidth else frameWidth
        val texHeight = if (target == blurTexture) blurHeight else frameHeight
        attachTarget(target)
        GLES20.glViewport(0, 0, texWidth, texHeight)
        GLES20.glUseProgram(blitProgram)
        bindVertexAttribs(blitProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, source)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(blitProgram, "uTexture"), 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(blitProgram, "uMirror"), mirror)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun drawBlur(target: Int, source: Int, stepX: Float, stepY: Float) {
        attachTarget(target)
        GLES20.glViewport(0, 0,
            if (target == blurTexture) blurWidth else frameWidth,
            if (target == blurTexture) blurHeight else frameHeight)
        GLES20.glUseProgram(blurProgram)
        bindVertexAttribs(blurProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, source)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(blurProgram, "uTexture"), 0)
        GLES20.glUniform2f(GLES20.glGetUniformLocation(blurProgram, "uStep"), stepX, stepY)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun attachTarget(target: Int) {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, framebuffer)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D, target, 0,
        )
    }

    private fun drawComposite(effectType: String, mirrored: Boolean, rotationDegrees: Int) {
        attachTarget(outputTexture)
        GLES20.glViewport(0, 0, frameWidth, frameHeight)
        GLES20.glUseProgram(compositeProgram)
        bindVertexAttribs(compositeProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, foregroundTexture)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(compositeProgram, "uForeground"), 0)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        val isReplacement = effectType == "replaceImage"
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, if (isReplacement) replacementTexture else backgroundTexture)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(compositeProgram, "uBackground"), 1)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(compositeProgram, "uReplacement"), if (isReplacement) 1f else 0f)
        val radians = Math.toRadians(rotationDegrees.toDouble())
        GLES20.glUniform2f(GLES20.glGetUniformLocation(compositeProgram, "uRotation"), cos(radians).toFloat(), sin(radians).toFloat())
        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, maskTexture)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(compositeProgram, "uMask"), 2)
        GLES20.glUniform1f(
            GLES20.glGetUniformLocation(compositeProgram, "uMirror"),
            if (mirrored) 1f else 0f,
        )
        // Cover-fit the replacement image, matching the centre crop the CPU
        // path did, so a still backdrop is never stretched.
        val scaleX: Float
        val scaleY: Float
        if (isReplacement && backdropWidth > 0 && backdropHeight > 0) {
            val frameAspect = if (rotationDegrees % 180 == 0) frameWidth.toFloat() / frameHeight
                else frameHeight.toFloat() / frameWidth
            val backdropAspect = backdropWidth.toFloat() / backdropHeight
            if (backdropAspect > frameAspect) {
                scaleX = frameAspect / backdropAspect
                scaleY = 1f
            } else {
                scaleX = 1f
                scaleY = backdropAspect / frameAspect
            }
        } else {
            scaleX = 1f
            scaleY = 1f
        }
        GLES20.glUniform2f(
            GLES20.glGetUniformLocation(compositeProgram, "uBackdropScale"), scaleX, scaleY,
        )
        GLES20.glUniform2f(
            GLES20.glGetUniformLocation(compositeProgram, "uBackdropOffset"),
            (1f - scaleX) / 2f, (1f - scaleY) / 2f,
        )
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun bindVertexAttribs(program: Int) {
        val pos = glPositionHandle(program)
        val coord = glTexCoordHandle(program)
        vertices.position(0)
        GLES20.glVertexAttribPointer(pos, 2, GLES20.GL_FLOAT, false, 16, vertices)
        GLES20.glEnableVertexAttribArray(pos)
        vertices.position(2)
        GLES20.glVertexAttribPointer(coord, 2, GLES20.GL_FLOAT, false, 16, vertices)
        GLES20.glEnableVertexAttribArray(coord)
    }

    private fun uploadTexture(
        texture: Int,
        data: ByteBuffer,
        width: Int,
        height: Int,
        rowStride: Int,
    ) {
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
        if (rowStride == width * 4) {
            // `glTexImage2D` reads from the buffer's position up to its limit, so
            // both are normalised first. A capture buffer can arrive with a
            // non-zero position or a sliced limit, which would otherwise upload
            // the wrong bytes and produce a black or corrupt frame.
            val view = data.duplicate()
            view.position(0)
            view.limit(width * height * 4)
            GLES20.glTexImage2D(
                GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, width, height, 0,
                GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, view,
            )
        } else {
            // Rare: a capture buffer with padded rows. Repack once here instead
            // of uploading the texture a row at a time.
            val rowBytes = width * 4
            val total = rowBytes * height
            var tight = rowScratch
            if (tight == null || tight.capacity() < total) {
                tight = ByteBuffer.allocateDirect(total).order(ByteOrder.nativeOrder())
                rowScratch = tight
            }
            tight.clear()
            val row = ByteArray(rowBytes)
            val source = data.duplicate()
            source.position(0)
            for (y in 0 until height) {
                val start = y * rowStride
                if (start + rowBytes > source.limit()) break
                source.position(start)
                source.get(row)
                tight.put(row)
            }
            // `flip()` sets the limit to what was written and rewinds the
            // position. Assigning the limit directly would throw, because the
            // buffer's limit is still at its capacity here.
            tight.flip()
            GLES20.glTexImage2D(
                GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, width, height, 0,
                GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, tight,
            )
        }
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
        )
    }

    private fun uploadBackdrop(backdrop: Bitmap) {
        // The still image is scaled into the full-size background texture so
        // the composite shader can sample both sides with the same coordinates.
        val buffer = ByteBuffer.allocateDirect(backdrop.byteCount)
            .order(ByteOrder.nativeOrder())
        backdrop.copyPixelsToBuffer(buffer)
        buffer.position(0)
        uploadTexture(
            replacementTexture, buffer, backdrop.width, backdrop.height, backdrop.width * 4,
        )
        backdropWidth = backdrop.width
        backdropHeight = backdrop.height
        backdropIdentity = System.identityHashCode(backdrop)
    }

    private fun uploadMask(mask: ByteBuffer, width: Int, height: Int) {
        uploadTexture(maskTexture, mask, width, height, width * 4)
    }

    private fun resizeIfNeeded(
        width: Int,
        height: Int,
        newMaskWidth: Int,
        newMaskHeight: Int,
        blurDivisor: Int,
    ) {
        val newBlurWidth = (width / blurDivisor).coerceAtLeast(1)
        val newBlurHeight = (height / blurDivisor).coerceAtLeast(1)
        if (width == frameWidth && height == frameHeight &&
            newMaskWidth == maskWidth && newMaskHeight == maskHeight &&
            newBlurWidth == blurWidth && newBlurHeight == blurHeight
        ) return
        if (foregroundTexture != 0) {
            val old = intArrayOf(foregroundTexture, backgroundTexture, maskTexture, outputTexture, blurTexture, replacementTexture)
            GLES20.glDeleteTextures(old.size, old, 0)
        }
        if (framebuffer != 0) GLES20.glDeleteFramebuffers(1, intArrayOf(framebuffer), 0)
        frameWidth = width
        frameHeight = height
        maskWidth = newMaskWidth
        maskHeight = newMaskHeight
        blurWidth = newBlurWidth
        blurHeight = newBlurHeight
        val ids = IntArray(6)
        GLES20.glGenTextures(ids.size, ids, 0)
        foregroundTexture = ids[0]
        backgroundTexture = ids[1]
        maskTexture = ids[2]
        outputTexture = ids[3]
        blurTexture = ids[4]
        replacementTexture = ids[5]
        for (id in ids) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, id)
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
            )
        }
        allocateTexture(foregroundTexture, width, height)
        allocateTexture(backgroundTexture, width, height)
        allocateTexture(outputTexture, width, height)
        allocateTexture(maskTexture, maxOf(1, newMaskWidth), maxOf(1, newMaskHeight))
        allocateTexture(blurTexture, blurWidth, blurHeight)
        allocateTexture(replacementTexture, 1, 1)
        val fb = IntArray(1)
        GLES20.glGenFramebuffers(1, fb, 0)
        framebuffer = fb[0]
        backdropIdentity = 0
        backdropWidth = 0
        backdropHeight = 0
    }

    private fun allocateTexture(texture: Int, width: Int, height: Int) {
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, width, height, 0,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null,
        )
    }

    private fun ensureReady() {
        if (ready) return
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        check(display != EGL14.EGL_NO_DISPLAY) { "No EGL display for the video effects renderer." }
        val version = IntArray(2)
        check(EGL14.eglInitialize(display, version, 0, version, 1)) {
            "Could not initialize EGL for the video effects renderer."
        }
        val configAttributes = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val configCount = IntArray(1)
        // eglChooseConfig(display, attribs, attribsOffset, configs, configsOffset,
        //                  configSize, numConfigs, numConfigsOffset)
        check(EGL14.eglChooseConfig(
            display, configAttributes, 0, configs, 0, 1, configCount, 0,
        ) && configCount[0] > 0
        ) { "No suitable EGL config for the video effects renderer." }
        val contextAttributes = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        context = EGL14.eglCreateContext(
            display, configs[0], EGL14.EGL_NO_CONTEXT, contextAttributes, 0,
        )
        check(context != EGL14.EGL_NO_CONTEXT) { "Could not create the EGL context." }
        surface = EGL14.eglCreatePbufferSurface(
            display, configs[0],
            intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
        )
        check(surface != EGL14.EGL_NO_SURFACE) { "Could not create the offscreen EGL surface." }
        check(EGL14.eglMakeCurrent(display, surface, surface, context)) {
            "Could not make the EGL context current."
        }
        blitProgram = buildProgram(BLIT_VERTEX_SHADER, BLIT_FRAGMENT_SHADER)
        compositeProgram = buildProgram(BLIT_VERTEX_SHADER, COMPOSITE_FRAGMENT_SHADER)
        blurProgram = buildProgram(BLIT_VERTEX_SHADER, BLUR_FRAGMENT_SHADER)
        ready = true
    }

    private fun buildProgram(vertexSource: String, fragmentSource: String): Int {
        val vertex = compileShader(GLES20.GL_VERTEX_SHADER, vertexSource, "vertex")
        val fragment = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource, "fragment")
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertex)
        GLES20.glAttachShader(program, fragment)
        GLES20.glLinkProgram(program)
        val linked = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linked, 0)
        if (linked[0] == 0) {
            val log = GLES20.glGetProgramInfoLog(program)
            GLES20.glDeleteProgram(program)
            android.util.Log.e("VideoEffects", "Program link failed. log=[$log]")
            error("Could not link the video effects shader: $log")
        }
        GLES20.glDeleteShader(vertex)
        GLES20.glDeleteShader(fragment)
        return program
    }

    private fun compileShader(type: Int, source: String, name: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            val log = GLES20.glGetShaderInfoLog(shader)
            GLES20.glDeleteShader(shader)
            error("Could not compile the $name shader: $log")
        }
        return shader
    }

    private fun glPositionHandle(program: Int) = GLES20.glGetAttribLocation(program, "aPosition")

    private fun glTexCoordHandle(program: Int) = GLES20.glGetAttribLocation(program, "aTexCoord")

    fun release() {
        if (ready) {
            val textures = intArrayOf(
                foregroundTexture, backgroundTexture, maskTexture,
                outputTexture, blurTexture, replacementTexture,
            )
            GLES20.glDeleteTextures(textures.size, textures, 0)
            GLES20.glDeleteFramebuffers(1, intArrayOf(framebuffer), 0)
            GLES20.glDeleteProgram(blitProgram)
            GLES20.glDeleteProgram(compositeProgram)
            GLES20.glDeleteProgram(blurProgram)
        }
        if (display != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(
                display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT,
            )
            if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface)
            if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context)
            EGL14.eglTerminate(display)
        }
        display = EGL14.EGL_NO_DISPLAY
        context = EGL14.EGL_NO_CONTEXT
        surface = EGL14.EGL_NO_SURFACE
        ready = false
    }

    private companion object {
        val BLIT_VERTEX_SHADER = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = aPosition;
                vTexCoord = aTexCoord;
            }
        """.trimIndent()

        /**
         * A straight textured quad. Also used to produce the blur: sampling a
         * full-size texture into a much smaller one, then back out to full
         * size, is a box blur that runs entirely on the GPU.
         */
        val BLIT_FRAGMENT_SHADER = """
            precision mediump float;
            uniform sampler2D uTexture;
            uniform float uMirror;
            varying vec2 vTexCoord;
            void main() {
                float u = uMirror > 0.5 ? 1.0 - vTexCoord.x : vTexCoord.x;
                vec4 color = texture2D(uTexture, vec2(u, vTexCoord.y));
                // Camera buffers do not always carry a meaningful alpha, and a
                // zero here would make the whole preview transparent. The
                // background effect is always fully opaque.
                gl_FragColor = vec4(color.rgb, 1.0);
            }
        """.trimIndent()

        // A separable Gaussian blur, with paired taps combined by GL_LINEAR.
        val BLUR_FRAGMENT_SHADER = """
            precision mediump float;
            uniform sampler2D uTexture;
            uniform vec2 uStep;
            varying vec2 vTexCoord;
            void main() {
                vec3 color = texture2D(uTexture, vTexCoord).rgb * 0.227027;
                color += texture2D(uTexture, vTexCoord + uStep * 1.384615).rgb * 0.316216;
                color += texture2D(uTexture, vTexCoord - uStep * 1.384615).rgb * 0.316216;
                color += texture2D(uTexture, vTexCoord + uStep * 3.230769).rgb * 0.070270;
                color += texture2D(uTexture, vTexCoord - uStep * 3.230769).rgb * 0.070270;
                gl_FragColor = vec4(color, 1.0);
            }
        """.trimIndent()

        /**
         * The whole background effect in one pass: the person comes from the
         * foreground texture, the replacement of it from the background
         * texture, and the matte decides which wins at every pixel.
         */
        val COMPOSITE_FRAGMENT_SHADER = """
            precision mediump float;
            uniform sampler2D uForeground;
            uniform sampler2D uBackground;
            uniform sampler2D uMask;
            uniform float uMirror;
            uniform vec2 uBackdropScale;
            uniform vec2 uBackdropOffset;
            uniform vec2 uRotation;
            uniform float uReplacement;
            varying vec2 vTexCoord;
            void main() {
                float u = uMirror > 0.5 ? 1.0 - vTexCoord.x : vTexCoord.x;
                vec2 mirrored = vec2(u, vTexCoord.y);
                vec4 foreground = texture2D(uForeground, mirrored);
                // Centre-crop the replacement image so it covers the frame
                // without being stretched, matching the CPU path.
                vec2 backdropUv = vTexCoord;
                if (uReplacement > 0.5) {
                    vec2 centered = vTexCoord - vec2(0.5);
                    // Sensor coordinates -> upright image coordinates.
                    backdropUv = vec2(uRotation.x * centered.x - uRotation.y * centered.y,
                                      uRotation.y * centered.x + uRotation.x * centered.y) + vec2(0.5);
                    backdropUv = backdropUv * uBackdropScale + uBackdropOffset;
                }
                vec4 background = texture2D(uBackground, backdropUv);
                float alpha = texture2D(uMask, mirrored).a;
                gl_FragColor = vec4(mix(background.rgb, foreground.rgb, alpha), 1.0);
            }
        """.trimIndent()

        fun floatBufferOf(vararg values: Float): FloatBuffer {
            val buffer = ByteBuffer.allocateDirect(values.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
            buffer.put(values).position(0)
            return buffer
        }
    }
}
