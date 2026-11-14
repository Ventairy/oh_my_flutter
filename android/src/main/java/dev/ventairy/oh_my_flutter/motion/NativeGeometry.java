package dev.ventairy.oh_my_flutter.motion;

import java.nio.ByteBuffer;

final class NativeGeometry {
    static {
        System.loadLibrary("omf_motion_particles");
    }

    static native void fill(ByteBuffer output, int width, int height,
        int columns, int rows, int seed, double[] geometryParameters);
}
