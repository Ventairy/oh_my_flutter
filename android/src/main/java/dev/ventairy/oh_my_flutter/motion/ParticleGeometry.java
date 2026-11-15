package dev.ventairy.oh_my_flutter.motion;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

final class ParticleGeometry {
    static final int ATTRIBUTE_STRIDE_BYTES = 10 * Float.BYTES;

    final int columns;
    final int rows;
    final int particleCount;
    final double maximumCellWidth;
    final double maximumCellHeight;
    private final ByteBuffer attributes;

    ParticleGeometry(DisintegrateConfiguration configuration) {
        double cellSize = Math.max(configuration.minimumCellSize,
            Math.sqrt((double) configuration.width * configuration.height / configuration.maximumParticleCount));
        columns = Math.min(configuration.maximumParticleCount, (int) Math.ceil(configuration.width / cellSize));
        rows = Math.min((int) Math.ceil(configuration.height / cellSize), configuration.maximumParticleCount / columns);
        particleCount = Math.multiplyExact(columns, rows);
        ByteBuffer storage = ByteBuffer.allocateDirect(Math.multiplyExact(particleCount, ATTRIBUTE_STRIDE_BYTES))
            .order(ByteOrder.nativeOrder());
        NativeGeometry.fill(storage, configuration.width, configuration.height, columns, rows,
            configuration.seed, configuration.geometryParameters);
        attributes = storage.asReadOnlyBuffer().order(ByteOrder.nativeOrder());
        maximumCellWidth = (double) configuration.width / columns + Math.ulp((float) configuration.width);
        maximumCellHeight = (double) configuration.height / rows + Math.ulp((float) configuration.height);
    }

    ByteBuffer createUploadView() {
        return attributes.duplicate().order(ByteOrder.nativeOrder());
    }
}
