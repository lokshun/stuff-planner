"""Génère la planche de sprites de la flèche 3D (`make arrow`).

CONTRAT
- render(cols, rows, size) -> bytes : TGA 32 bits non compressé, origine en bas à gauche,
  cols x rows images carrées de `size` pixels. L'image k (rangée = k // cols, colonne =
  k % cols, en partant du haut) montre la flèche tournée de k * 2π / (cols * rows) dans le
  sens antihoraire vue du dessus : k = 0 droit devant, k = N/4 vers la gauche.
- Dard à encoche en relief (arête centrale, forme de la flèche de la minicarte), contour noir, vue de derrière et au-dessus, ombrée en gris : la teinte
  est appliquée en jeu (Texture:SetVertexColor). Lumière fixe : l'ombrage change en tournant.
- main() écrit StuffPlanner/Media/Arrow3D.tga (16 x 8 images de 64 px, 1024 x 512).
- Rendu pur Python (aucune dépendance), suréchantillonnage SS x SS par pixel.
"""

import math
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "StuffPlanner" / "Media" / "Arrow3D.tga"

SS = 3
PITCH = math.radians(60)  # inclinaison de la caméra sous l'horizon
PERSPECTIVE = 3.2  # distance de la caméra, en longueurs de flèche
EDGE_Z, RIDGE_Z, BOTTOM_Z = 0.06, 0.3, -0.08
LIGHT = (-0.45, 0.35, 0.82)

# Dard à encoche, comme la flèche du joueur de la minicarte (Interface\Minimap\MinimapArrow).
# Contour (x à droite, y devant), sens antihoraire vu du dessus ; pointe et encoche sur l'arête.
OUTLINE = [
    (0.0, 1.0),
    (-0.68, -0.78),
    (0.0, -0.42),
    (0.68, -0.78),
]
OUTLINE_PX = 1.6  # contour sombre autour de la flèche, en pixels de l'image finale


def _normalize(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _top(x, y):
    return (x, y, RIDGE_Z if x == 0.0 else EDGE_Z)


def mesh():
    """Triangles (a, b, c) en 3D ; l'orientation est corrigée au rendu."""
    tip, left, notch, right = OUTLINE
    tris = []
    # Dessus : deux pans inclinés de part et d'autre de l'arête pointe-encoche.
    for wing in (left, right):
        tris.append((_top(*tip), _top(*wing), _top(*notch)))
        tris.append(tuple((x, y, BOTTOM_Z) for x, y in (tip, wing, notch)))
    # Côtés.
    for i, a in enumerate(OUTLINE):
        b = OUTLINE[(i + 1) % len(OUTLINE)]
        a0, b0 = (a[0], a[1], BOTTOM_Z), (b[0], b[1], BOTTOM_Z)
        a1, b1 = _top(*a), _top(*b)
        tris.append((a0, b0, b1))
        tris.append((a0, b1, a1))
    return tris


def _shade(normal):
    lit = max(0.0, sum(n * l for n, l in zip(normal, _normalize(LIGHT))))
    half = _normalize((LIGHT[0], LIGHT[1] - math.cos(PITCH), LIGHT[2] + math.sin(PITCH)))
    spec = max(0.0, sum(n * h for n, h in zip(normal, half))) ** 24
    return min(1.0, 0.28 + 0.62 * lit + 0.45 * spec)


def _project(p, scale, center):
    # Caméra derrière et au-dessus : regarde vers +y en plongée de PITCH.
    fwd = (0.0, math.cos(PITCH), -math.sin(PITCH))
    up = (0.0, math.sin(PITCH), math.cos(PITCH))
    depth = sum(a * b for a, b in zip(p, fwd))
    k = PERSPECTIVE / (PERSPECTIVE + depth)
    sx = center + p[0] * k * scale
    sy = center - sum(a * b for a, b in zip(p, up)) * k * scale
    return sx, sy, depth


def render_frame(angle, size):
    n = size * SS
    scale = n * 0.40
    center = n / 2.0
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    depth = [math.inf] * (n * n)
    shade = [0.0] * (n * n)
    for tri in mesh():
        pts = [(x * cos_a - y * sin_a, x * sin_a + y * cos_a, z) for x, y, z in tri]
        normal = _normalize(_cross(_sub(pts[1], pts[0]), _sub(pts[2], pts[0])))
        if normal[2] * math.sin(PITCH) - normal[1] * math.cos(PITCH) < 0:
            normal = (-normal[0], -normal[1], -normal[2])  # face visible : tournée vers la caméra
        value = _shade(normal)
        (x0, y0, d0), (x1, y1, d1), (x2, y2, d2) = [_project(p, scale, center) for p in pts]
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue
        lo_x, hi_x = max(0, int(min(x0, x1, x2))), min(n - 1, int(max(x0, x1, x2)) + 1)
        lo_y, hi_y = max(0, int(min(y0, y1, y2))), min(n - 1, int(max(y0, y1, y2)) + 1)
        for py in range(lo_y, hi_y + 1):
            cy = py + 0.5
            for px in range(lo_x, hi_x + 1):
                cx = px + 0.5
                w0 = ((x1 - cx) * (y2 - cy) - (x2 - cx) * (y1 - cy)) / area
                w1 = ((x2 - cx) * (y0 - cy) - (x0 - cx) * (y2 - cy)) / area
                w2 = 1.0 - w0 - w1
                if w0 < 0 or w1 < 0 or w2 < 0:
                    continue
                d = w0 * d0 + w1 * d1 + w2 * d2
                i = py * n + px
                if d < depth[i]:
                    depth[i] = d
                    shade[i] = value
    pixels = _resolve(depth, shade, size, n)
    return _outline(pixels, size)


def _outline(pixels, size):
    """Pose la flèche sur un contour noir : alpha du contour = max du voisinage (rayon OUTLINE_PX)."""
    reach = int(math.ceil(OUTLINE_PX))
    out = []
    for y in range(size):
        row = []
        for x in range(size):
            gray, _, _, alpha = pixels[y][x]
            ring = 0
            for dy in range(-reach, reach + 1):
                for dx in range(-reach, reach + 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < size and 0 <= xx < size:
                        weight = max(0.0, min(1.0, OUTLINE_PX + 0.5 - math.hypot(dx, dy)))
                        ring = max(ring, pixels[yy][xx][3] * weight)
            a = alpha / 255
            total = a + ring / 255 * (1 - a)
            value = int(round(gray * a / total)) if total > 0 else 0
            row.append((value, value, value, int(round(255 * total))))
        out.append(row)
    return out


def _resolve(depth, shade, size, n):
    pixels = []
    for y in range(size):
        row = []
        for x in range(size):
            total = covered = 0
            for sy in range(SS):
                base = (y * SS + sy) * n + x * SS
                for sx in range(SS):
                    if depth[base + sx] != math.inf:
                        covered += 1
                        total += shade[base + sx]
            if covered:
                gray = int(round(255 * total / covered))
                row.append((gray, gray, gray, int(round(255 * covered / (SS * SS)))))
            else:
                row.append((0, 0, 0, 0))
        pixels.append(row)
    return pixels


def render(cols, rows, size):
    count = cols * rows
    width, height = cols * size, rows * size
    sheet = [[(0, 0, 0, 0)] * width for _ in range(height)]
    for k in range(count):
        frame = render_frame(k * 2 * math.pi / count, size)
        top, left = (k // cols) * size, (k % cols) * size
        for y, row in enumerate(frame):
            sheet[top + y][left:left + size] = row
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    body = bytearray()
    for row in reversed(sheet):  # TGA : première rangée en bas
        for r, g, b, a in row:
            body += bytes((b, g, r, a))
    return header + bytes(body)


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(render(16, 8, 64))
    print(f"Écrit {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
