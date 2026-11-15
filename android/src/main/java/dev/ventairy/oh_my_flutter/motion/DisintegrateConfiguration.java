package dev.ventairy.oh_my_flutter.motion;

import java.util.Arrays;
import java.util.Map;

final class DisintegrateConfiguration {
    final int width;
    final int height;
    final int viewportWidth;
    final int viewportHeight;
    final float originX;
    final float originY;
    final float scaleX;
    final float scaleY;
    final double pointPadding;
    final int maximumParticleCount;
    final double minimumCellSize;
    final int seed;
    final double[] geometryParameters;
    final String vertexSource;
    final String fragmentSource;

    DisintegrateConfiguration(Map<?, ?> arguments) {
        width = ((Number) arguments.get("width")).intValue();
        height = ((Number) arguments.get("height")).intValue();
        viewportWidth = ((Number) arguments.get("viewportWidth")).intValue();
        viewportHeight = ((Number) arguments.get("viewportHeight")).intValue();
        originX = ((Number) arguments.get("originX")).floatValue();
        originY = ((Number) arguments.get("originY")).floatValue();
        scaleX = ((Number) arguments.get("scaleX")).floatValue();
        scaleY = ((Number) arguments.get("scaleY")).floatValue();
        pointPadding = ((Number) arguments.get("pointPadding")).doubleValue();
        maximumParticleCount = ((Number) arguments.get("maximumParticleCount")).intValue();
        minimumCellSize = ((Number) arguments.get("minimumCellSize")).doubleValue();
        seed = ((Number) arguments.get("seed")).intValue();
        geometryParameters = ((double[]) arguments.get("geometryParameters")).clone();
        vertexSource = (String) arguments.get("vertexSource");
        fragmentSource = (String) arguments.get("fragmentSource");
        if (width <= 0 || height <= 0 || viewportWidth <= 0 || viewportHeight <= 0 || maximumParticleCount <= 0) {
            throw new IllegalArgumentException("Image, viewport and particle counts must be positive.");
        }
        if (!Float.isFinite(originX) || !Float.isFinite(originY)
                || !Float.isFinite(scaleX) || !Float.isFinite(scaleY) || scaleX <= 0 || scaleY <= 0
                || !Double.isFinite(pointPadding) || pointPadding < 0
                || !Double.isFinite(minimumCellSize) || minimumCellSize <= 0 || seed == 0) {
            throw new IllegalArgumentException("Expected finite geometry values, positive scales and a nonzero seed.");
        }
        if (geometryParameters.length != 10) throw new IllegalArgumentException("Expected ten geometry parameters.");
        for (double value : geometryParameters) {
            if (!Double.isFinite(value)) throw new IllegalArgumentException("Geometry parameters must be finite.");
        }
        if (vertexSource == null || fragmentSource == null || vertexSource.isEmpty() || fragmentSource.isEmpty()) {
            throw new IllegalArgumentException("Both particle shaders are required.");
        }
    }

    boolean matches(DisintegrateConfiguration other) {
        return width == other.width && height == other.height
            && viewportWidth == other.viewportWidth && viewportHeight == other.viewportHeight
            && originX == other.originX && originY == other.originY
            && scaleX == other.scaleX && scaleY == other.scaleY
            && pointPadding == other.pointPadding
            && maximumParticleCount == other.maximumParticleCount
            && minimumCellSize == other.minimumCellSize && seed == other.seed
            && Arrays.equals(geometryParameters, other.geometryParameters)
            && vertexSource.equals(other.vertexSource) && fragmentSource.equals(other.fragmentSource);
    }
}
