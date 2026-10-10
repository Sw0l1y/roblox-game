"""Rough software render of a simulated world (tools/sim/run.mjs writes world.json) for layout checks.

Usage: python3 tools/sim/render.py <world.json> <out_prefix> [--size 960x540]
Writes <out_prefix>-spawn.png (player camera at spawn), -overview.png (45 degrees from above) and -map.png (top down).
Flat-shaded parts with sun + ambient light, sky gradient and distance haze from the game's Lighting. It is a
blockout-level preview (no textures, meshes drawn as boxes), good for composition, scale and colour checks.
"""
import json
import math
import sys

import numpy as np
from PIL import Image


def cf_matrix(c):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c
    return np.array([[r00, r01, r02], [r10, r11, r12], [r20, r21, r22]], dtype=np.float64), np.array([x, y, z], dtype=np.float64)


def box_mesh():
    v = np.array([[x, y, z] for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)], dtype=np.float64)
    # faces as quads (indices into v): -x, +x, -y, +y, -z, +z
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    tris = []
    for a, b, c, d in quads:
        tris += [(a, b, c), (a, c, d)]
    return v, np.array(tris)


def wedge_mesh():
    # Roblox wedge: full bottom, full back (+Z) face, slope from top-back down to bottom-front.
    v = np.array([[-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [-0.5, -0.5, 0.5], [0.5, -0.5, 0.5], [-0.5, 0.5, 0.5], [0.5, 0.5, 0.5]], dtype=np.float64)
    tris = [(0, 1, 3), (0, 3, 2), (2, 3, 5), (2, 5, 4), (0, 4, 5), (0, 5, 1), (0, 2, 4), (1, 5, 3)]
    return v, np.array(tris)


def sphere_mesh(rings=8, segs=14):
    verts = [[0, 0.5, 0]]
    for i in range(1, rings):
        phi = math.pi * i / rings
        for j in range(segs):
            th = 2 * math.pi * j / segs
            verts.append([0.5 * math.sin(phi) * math.cos(th), 0.5 * math.cos(phi), 0.5 * math.sin(phi) * math.sin(th)])
    verts.append([0, -0.5, 0])
    tris = []
    for j in range(segs):
        tris.append((0, 1 + (j + 1) % segs, 1 + j))
    for i in range(rings - 2):
        for j in range(segs):
            a = 1 + i * segs + j
            b = 1 + i * segs + (j + 1) % segs
            c = 1 + (i + 1) * segs + j
            d = 1 + (i + 1) * segs + (j + 1) % segs
            tris += [(a, b, d), (a, d, c)]
    last = len(verts) - 1
    base = 1 + (rings - 2) * segs
    for j in range(segs):
        tris.append((last, base + j, base + (j + 1) % segs))
    return np.array(verts, dtype=np.float64), np.array(tris)


def cylinder_mesh(segs=16):
    # Roblox cylinder axis is X
    verts = []
    for j in range(segs):
        th = 2 * math.pi * j / segs
        verts.append([-0.5, 0.5 * math.cos(th), 0.5 * math.sin(th)])
        verts.append([0.5, 0.5 * math.cos(th), 0.5 * math.sin(th)])
    verts.append([-0.5, 0, 0])
    verts.append([0.5, 0, 0])
    c0, c1 = len(verts) - 2, len(verts) - 1
    tris = []
    for j in range(segs):
        a, b = 2 * j, 2 * j + 1
        c, d = 2 * ((j + 1) % segs), 2 * ((j + 1) % segs) + 1
        tris += [(a, c, d), (a, d, b), (c0, c, a), (c1, b, d)]
    return np.array(verts, dtype=np.float64), np.array(tris)


MESHES = {"Block": box_mesh(), "Wedge": wedge_mesh(), "Ball": sphere_mesh(), "Cylinder": cylinder_mesh(), "CornerWedge": box_mesh(), "Mesh": box_mesh()}


def sky_color(light, t):
    atm = light.get("atmosphere") or {}
    clock = light.get("clock", 14) or 14
    night = clock < 6 or clock > 19
    top = np.array([0.36, 0.62, 0.95]) if not night else np.array([0.04, 0.05, 0.12])
    hz = np.array(atm.get("color", [0.78, 0.88, 1.0])) if atm else np.array([0.8, 0.88, 1.0])
    if night:
        hz = hz * 0.35
    return top * (1 - t) + hz * t


def render(world, cam_pos, cam_target, w, h, fov=70.0, ortho=None):
    light = world.get("light", {})
    atm = light.get("atmosphere") or {}
    haze_col = np.array(atm.get("color", [0.8, 0.88, 1.0]))
    density = atm.get("density", 0.3) if atm else 0.2
    clock = light.get("clock", 14) or 14
    night = clock < 6 or clock > 19
    sun = np.array([0.45, 0.8, 0.35])
    sun /= np.linalg.norm(sun)
    amb = np.array(light.get("outdoor", [0.6, 0.6, 0.65])) * 0.6 + np.array(light.get("ambient", [0.4, 0.4, 0.45])) * 0.4
    sun_strength = 0.15 if night else 0.75

    fwd = np.array(cam_target, dtype=np.float64) - np.array(cam_pos, dtype=np.float64)
    fwd /= np.linalg.norm(fwd)
    up0 = np.array([0, 1.0, 0]) if abs(fwd[1]) < 0.99 else np.array([0, 0, -1.0])
    right = np.cross(fwd, up0)
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    cam = np.array(cam_pos, dtype=np.float64)
    f = (h / 2) / math.tan(math.radians(fov / 2))

    # sky background
    img = np.zeros((h, w, 3))
    ys = np.linspace(0, 1, h)[:, None]
    for i in range(h):
        img[i, :, :] = sky_color(light, min(1.0, ys[i, 0] * 1.6))
    depth = np.full((h, w), np.inf)
    near = 0.3

    for part in world["parts"]:
        cls, shape, c, size, color, transp, mat = part[0], part[1], part[2], part[3], part[4], part[5], part[6]
        if transp > 0.6:
            continue
        verts, tris = MESHES.get(shape, MESHES["Block"])
        size = np.array(size, dtype=np.float64)
        if shape == "Ball":
            size = np.full(3, min(size))
        elif shape == "Cylinder":
            d = min(size[1], size[2])
            size = np.array([size[0], d, d])
        R, p = cf_matrix(c)
        wv = (verts * size) @ R.T + p
        rel = wv - cam
        if ortho is None:
            cz = rel @ fwd
            if cz.max() < near:
                continue
            cx = rel @ right
            cy = rel @ up
        else:
            cz = rel @ fwd
            cx = rel @ right
            cy = rel @ up
        base = np.array(color, dtype=np.float64)
        neon = mat == "Neon"
        for tri in tris:
            a, b, cc = wv[tri[0]], wv[tri[1]], wv[tri[2]]
            n = np.cross(b - a, cc - a)
            nl = np.linalg.norm(n)
            if nl < 1e-12:
                continue
            n /= nl
            # polygon in camera space, clipped against the near plane
            poly = [(cx[i], cy[i], cz[i]) for i in tri]
            if ortho is None:
                clipped = []
                for k in range(3):
                    p1, p2 = poly[k], poly[(k + 1) % 3]
                    in1, in2 = p1[2] >= near, p2[2] >= near
                    if in1:
                        clipped.append(p1)
                    if in1 != in2:
                        t = (near - p1[2]) / (p2[2] - p1[2])
                        clipped.append(tuple(p1[m] + (p2[m] - p1[m]) * t for m in range(3)))
                if len(clipped) < 3:
                    continue
                poly = clipped
            if neon:
                col = np.minimum(1.0, base * 1.25 + 0.1)
            else:
                lam = max(0.0, float(n @ sun))
                col = base * (amb + sun_strength * lam + 0.25 * max(0.0, float(n[1])))
            # haze by distance from camera
            centroid = (a + b + cc) / 3
            dist = float(np.linalg.norm(centroid - cam))
            fogt = 1 - math.exp(-dist * density * 0.004)
            col = col * (1 - fogt) + haze_col * fogt * (0.35 if night else 1.0)
            col = np.clip(col, 0, 1)
            for k in range(1, len(poly) - 1):
                tri_pts = [poly[0], poly[k], poly[k + 1]]
                if ortho is None:
                    sx = [w / 2 + q[0] / q[2] * f for q in tri_pts]
                    sy = [h / 2 - q[1] / q[2] * f for q in tri_pts]
                else:
                    sx = [w / 2 + q[0] * ortho for q in tri_pts]
                    sy = [h / 2 - q[1] * ortho for q in tri_pts]
                sz = [q[2] for q in tri_pts]
                x0, x1 = max(int(math.floor(min(sx))), 0), min(int(math.ceil(max(sx))), w - 1)
                y0, y1 = max(int(math.floor(min(sy))), 0), min(int(math.ceil(max(sy))), h - 1)
                if x0 > x1 or y0 > y1:
                    continue
                area = (sx[1] - sx[0]) * (sy[2] - sy[0]) - (sx[2] - sx[0]) * (sy[1] - sy[0])
                if abs(area) < 1e-9:
                    continue
                gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
                w0 = ((sx[1] - gx) * (sy[2] - gy) - (sx[2] - gx) * (sy[1] - gy)) / area
                w1 = ((sx[2] - gx) * (sy[0] - gy) - (sx[0] - gx) * (sy[2] - gy)) / area
                w2 = 1 - w0 - w1
                inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
                if not inside.any():
                    continue
                if ortho is None:
                    inv = w0 / sz[0] + w1 / sz[1] + w2 / sz[2]
                    zz = 1 / np.maximum(inv, 1e-9)
                else:
                    zz = w0 * sz[0] + w1 * sz[1] + w2 * sz[2]
                sub = depth[y0:y1 + 1, x0:x1 + 1]
                mask = inside & (zz < sub)
                if mask.any():
                    sub[mask] = zz[mask]
                    img[y0:y1 + 1, x0:x1 + 1][mask] = col
    return (np.clip(img, 0, 1) ** (1 / 1.1) * 255).astype(np.uint8)


def main():
    src, prefix = sys.argv[1], sys.argv[2]
    w, h = 960, 540
    if "--size" in sys.argv:
        w, h = map(int, sys.argv[sys.argv.index("--size") + 1].split("x"))
    world = json.load(open(src))
    # parts with broken (NaN) transforms export as null: skip them instead of failing the render
    parts = [p for p in world["parts"] if all(isinstance(v, (int, float)) and math.isfinite(v) for v in list(p[2]) + list(p[3]))]
    world["parts"] = parts
    if not parts:
        print("no parts")
        return
    mins = np.array([1e9, 1e9, 1e9])
    maxs = -mins
    for p in parts:
        pos = np.array(p[2][:3])
        mins = np.minimum(mins, pos)
        maxs = np.maximum(maxs, pos)
    center = (mins + maxs) / 2
    extent = float(np.max(maxs - mins))
    cams = world.get("cams", {})
    base = cams.get("char") or cams.get("spawn")
    if base:
        R, p = cf_matrix(base)
        look = -R[:, 2]
        look[1] = 0
        if np.linalg.norm(look) < 1e-6:
            look = np.array([0, 0, -1.0])
        look /= np.linalg.norm(look)
        eye = p + np.array([0, 4.5, 0]) - look * 13
        target = p + look * 20 + np.array([0, 1.5, 0])
        Image.fromarray(render(world, eye, target, w, h)).save(prefix + "-spawn.png")
    # Cutaway for the views from above: big slabs well above the player (ceilings, roofs) would hide indoor maps.
    above = world
    if base:
        cut = cf_matrix(base)[1][1] + 35
        above = dict(world, parts=[p for p in parts if not (p[2][1] > cut and p[3][0] * p[3][2] > 400)])
    eye = center + np.array([0.0, 0.6, 0.75]) * max(extent, 60) * 0.85
    Image.fromarray(render(above, eye, center, w, h, fov=60)).save(prefix + "-overview.png")
    eye = center + np.array([0.0, 500.0, 0.001])
    scale = min(w, h) / max(extent * 1.05, 20)
    Image.fromarray(render(above, eye, center, w, h, ortho=scale)).save(prefix + "-map.png")
    print("rendered", prefix + "-{spawn,overview,map}.png", len(parts), "parts")


if __name__ == "__main__":
    main()
