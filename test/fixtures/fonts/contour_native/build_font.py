"""Self-authored CC0 diagnostic font; no third-party outlines or images."""
from array import array
import math
from pathlib import Path
import struct
import zlib

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables.sbixGlyph import Glyph
from fontTools.ttLib.tables.sbixStrike import Strike
from fontTools.ttLib.tables._g_l_y_f import Glyph as OutlineGlyph, GlyphCoordinates
from fontTools.ttLib.tables.ttProgram import Program

ROOT = Path(__file__).resolve().parent


def png(size):
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            # Thin, antialiased white ring, authored analytically.
            distance = math.hypot(x + .5 - size / 2, y + .5 - size / 2)
            coverage = max(0, min(1, 1.0 - abs(distance - size * .3)))
            rows.extend((255, 255, 255, round(coverage * 255)))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows))) + chunk(b'IEND', b'')


font = FontBuilder(1000, isTTF=True)
font.setupGlyphOrder(['.notdef', 'space', 'A', 'x'])
font.setupCharacterMap({32: 'space', 65: 'A', 120: 'x'})
glyphs = {}
for name in ['.notdef', 'space', 'x']:
    glyphs[name] = TTGlyphPen(None).glyph()
bitmap_bounds = OutlineGlyph()
bitmap_bounds.numberOfContours = 2
bitmap_bounds.endPtsOfContours = [0, 1]
bitmap_bounds.coordinates = GlyphCoordinates([(0, 0), (1000, 1000)])
bitmap_bounds.flags = array('B', [1, 1])
bitmap_bounds.program = Program()
glyphs['x'] = bitmap_bounds
pen = TTGlyphPen(None)
# A simple authored filled shape with a curved top, rather than a borrowed letter.
pen.moveTo((50, 0))
pen.lineTo((50, 700))
pen.qCurveTo((350, 850), (650, 700))
pen.lineTo((650, 0))
pen.closePath()
glyphs['A'] = pen.glyph()
font.setupGlyf(glyphs)
font.setupHorizontalMetrics({'.notdef': (700, 0), 'space': (700, 0), 'A': (700, 50), 'x': (1000, 0)})
font.setupHorizontalHeader(ascent=900, descent=-100)
font.setupNameTable({
    'familyName': 'Contour Vector Fixture',
    'styleName': 'Regular',
    'uniqueFontIdentifier': 'ContourVectorFixture-Regular-v1',
    'fullName': 'Contour Vector Fixture Regular',
    'psName': 'ContourVectorFixture-Regular',
    'version': 'Version 1.0',
    'copyright': 'Self-authored diagnostic fixture, dedicated to the public domain under CC0-1.0.',
})
font.setupOS2(sTypoAscender=900, sTypoDescender=-100, usWinAscent=900, usWinDescent=100)
font.setupPost()
font.setupMaxp()
font.font.recalcTimestamp = False
font.font['head'].created = 2082844800
font.font['head'].modified = 2082844800
font.save(ROOT / 'contour_vector.ttf')
font.setupNameTable({
    'familyName': 'Contour Bitmap Fixture',
    'styleName': 'Regular',
    'uniqueFontIdentifier': 'ContourBitmapFixture-Regular-v1',
    'fullName': 'Contour Bitmap Fixture Regular',
    'psName': 'ContourBitmapFixture-Regular',
    'version': 'Version 1.0',
    'copyright': 'Self-authored diagnostic fixture, dedicated to the public domain under CC0-1.0.',
})
bitmap = newTable('sbix')
strike = Strike(ppem=32, resolution=72)
strike.glyphs['x'] = Glyph(glyphName='x', graphicType='png ', originOffsetX=0, originOffsetY=0, imageData=png(32))
bitmap.strikes[32] = strike
font.font['sbix'] = bitmap
font.save(ROOT / 'contour_mixed_bitmap.ttf')
