#include "particle_geometry.h"
#include <jni.h>
#include <stdint.h>

static void reject_arguments(JNIEnv* env, const char* message) {
    jclass type = (*env)->FindClass(env, "java/lang/IllegalArgumentException");
    if (type != NULL) (*env)->ThrowNew(env, type, message);
}

JNIEXPORT void JNICALL
Java_dev_ventairy_oh_1my_1flutter_motion_NativeGeometry_fill(
    JNIEnv* env, jclass type, jobject output, jint width, jint height,
    jint columns, jint rows, jint seed, jdoubleArray coefficients) {
    (void) type;
    if (width <= 0 || height <= 0 || columns <= 0 || rows <= 0 || seed == 0) {
        reject_arguments(env, "Dimensions, grid and nonzero seed are required.");
        return;
    }
    if (coefficients == NULL || (*env)->GetArrayLength(env, coefficients) != 10) {
        reject_arguments(env, "Expected ten motion coefficients.");
        return;
    }
    if (output == NULL) {
        reject_arguments(env, "Expected a direct ByteBuffer.");
        return;
    }
    float* attributes = (*env)->GetDirectBufferAddress(env, output);
    jlong capacity = (*env)->GetDirectBufferCapacity(env, output);
    const uint64_t particle_count = (uint64_t) columns * (uint64_t) rows;
    if (attributes == NULL || capacity < 0 || particle_count > (uint64_t) capacity / (10 * sizeof(float))) {
        reject_arguments(env, "The direct ByteBuffer is too small for this grid.");
        return;
    }
    double motion[10];
    (*env)->GetDoubleArrayRegion(env, coefficients, 0, 10, motion);
    if ((*env)->ExceptionCheck(env)) return;
    particle_geometry_fill(attributes, width, height, columns, rows, (uint32_t) seed, motion);
}
