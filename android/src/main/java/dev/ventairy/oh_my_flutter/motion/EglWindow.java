package dev.ventairy.oh_my_flutter.motion;

import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLExt;
import android.opengl.EGLSurface;
import android.view.Surface;

final class EglWindow {
    private EGLDisplay display = EGL14.EGL_NO_DISPLAY;
    private EGLContext context = EGL14.EGL_NO_CONTEXT;
    private EGLSurface surface = EGL14.EGL_NO_SURFACE;

    void initialize(Surface output) {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        if (display == EGL14.EGL_NO_DISPLAY) throw failure("eglGetDisplay");
        if (!EGL14.eglInitialize(display, new int[2], 0, new int[2], 0)) throw failure("eglInitialize");
        int[] attributes = {
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_DEPTH_SIZE, 0, EGL14.EGL_STENCIL_SIZE, 0,
            EGL14.EGL_RENDERABLE_TYPE, EGLExt.EGL_OPENGL_ES3_BIT_KHR,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT, EGL14.EGL_NONE,
        };
        EGLConfig[] configurations = new EGLConfig[1];
        int[] count = new int[1];
        if (!EGL14.eglChooseConfig(display, attributes, 0, configurations, 0, 1, count, 0) || count[0] == 0) {
            throw failure("RGBA8888 GLES3 configuration");
        }
        context = EGL14.eglCreateContext(display, configurations[0], EGL14.EGL_NO_CONTEXT,
            new int[] {EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE}, 0);
        if (context == EGL14.EGL_NO_CONTEXT) throw failure("eglCreateContext");
        surface = EGL14.eglCreateWindowSurface(display, configurations[0], output, new int[] {EGL14.EGL_NONE}, 0);
        if (surface == EGL14.EGL_NO_SURFACE) throw failure("eglCreateWindowSurface");
        if (!EGL14.eglMakeCurrent(display, surface, surface, context)) throw failure("eglMakeCurrent");
        if (!EGL14.eglSwapInterval(display, 0)) throw failure("eglSwapInterval");
    }

    void present(long frameTimeNs) {
        if (!EGLExt.eglPresentationTimeANDROID(display, surface, frameTimeNs)) {
            throw failure("eglPresentationTimeANDROID");
        }
        if (!EGL14.eglSwapBuffers(display, surface)) throw failure("eglSwapBuffers");
    }

    void release() {
        if (display == EGL14.EGL_NO_DISPLAY) return;
        EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
        if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface);
        if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context);
        EGL14.eglReleaseThread();
        EGL14.eglTerminate(display);
        surface = EGL14.EGL_NO_SURFACE;
        context = EGL14.EGL_NO_CONTEXT;
        display = EGL14.EGL_NO_DISPLAY;
    }

    private IllegalStateException failure(String operation) {
        return new IllegalStateException(operation + " failed: 0x" + Integer.toHexString(EGL14.eglGetError()));
    }
}
