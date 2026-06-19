import numpy as np
from PIL import Image


def deterministic_base_terrain(shape, seed=0):
    height, width = shape
    y = np.linspace(-1.0, 1.0, height)[:, None]
    x = np.linspace(-1.0, 1.0, width)[None, :]

    phase = (seed % 19) * 0.28
    continent_centers = [(-0.55, 0.30), (0.45, -0.18), (-0.15, -0.65), (0.22, 0.55)]
    continent = np.zeros((height, width), dtype=float)
    for i, (cx, cy) in enumerate(continent_centers):
        strength = 0.20 + 0.06 * np.cos(1.7 * i + phase * 0.9)
        spread = 3.2 + 0.5 * np.sin(0.8 * i + phase * 1.0)
        continent += np.exp(-(((x - cx) * spread) ** 2 + ((y - cy) * (spread * 0.8)) ** 2)) * strength

    arc_belts = np.exp(-((x + 0.1) ** 2 * 10.0 + (y - 0.3) ** 2 * 18.0)) * 0.14
    arc_belts += np.exp(-((x - 0.2) ** 2 * 12.0 + (y + 0.35) ** 2 * 16.0)) * 0.12
    ridge_chain = np.tanh(4.0 * (np.sin(2.5 * x + 1.9 * y + phase) + np.cos(1.8 * x - 2.3 * y - phase * 0.7))) * 0.08

    mountain_peaks = np.exp(-((x + 0.42) ** 2 * 18.0 + (y + 0.05) ** 2 * 18.0)) * 0.24
    mountain_peaks += np.exp(-((x - 0.32) ** 2 * 16.0 + (y - 0.4) ** 2 * 15.0)) * 0.20
    highlands = np.exp(-((x - 0.03) ** 2 * 8.0 + (y + 0.5) ** 2 * 12.0)) * 0.12

    continent_mask = np.clip(continent + 0.06 * np.sin(2.8 * x + phase * 0.7) - np.abs(y) * 0.18, 0.0, 1.0)
    land = continent_mask * (0.08 + ridge_chain + mountain_peaks + mountain_peaks * 0.4 + arc_belts + highlands)

    ocean_depth = -0.16 * np.exp(-((x + 0.75) ** 2 * 4.2 + (y - 0.5) ** 2 * 4.6))
    coast = np.exp(-((np.clip(continent_mask - 0.3, 0.0, 1.0)) ** 2) * 30.0) * -0.02
    detail = (np.sin(18.3 * x + 14.2 * y + phase * 1.8) * np.cos(9.1 * x - 11.7 * y - phase) * 0.014
              + np.sin(26.1 * x - 8.7 * y + phase * 1.3) * np.cos(12.4 * x + 16.2 * y - phase * 1.5) * 0.009)
    base = land + ocean_depth - 0.08 * (1.0 - continent_mask) + coast
    base += np.sin(5.8 * x + phase * 1.1) * 0.015 * continent_mask
    base += detail * continent_mask * 0.9
    return base


def normalize(heightmap):
    min_h = np.min(heightmap)
    max_h = np.max(heightmap)
    return (heightmap - min_h) / (max_h - min_h + 1e-12)


def apply_plate_tectonics(heightmap, strength=0.12, plates=6, seed=0):
    height, width = heightmap.shape
    y = np.linspace(-1.0, 1.0, height)[:, None]
    x = np.linspace(-1.0, 1.0, width)[None, :]
    plate_map = np.zeros_like(heightmap)
    plate_angles = 2 * np.pi * (np.arange(plates) / plates) + (seed % 17) * 0.14

    for angle in plate_angles:
        line = (x * np.cos(angle) + y * np.sin(angle))
        boundary = np.tanh(np.sin(5.1 * line + angle * 1.3))
        uplift = np.exp(-((line - 0.05 * np.sin(angle * 0.8)) ** 2) * 16.0) * 0.10
        trench = -np.exp(-((line + 0.18 * np.cos(angle * 0.9)) ** 2) * 20.0) * 0.04
        plate_map += (uplift * boundary + trench * (1.0 - np.abs(boundary))) * strength

    return heightmap + plate_map


def simulate_erosion(heightmap, iterations=20, talus=0.010):
    h = heightmap.copy()
    for _ in range(iterations):
        east = np.roll(h, -1, axis=1)
        south = np.roll(h, -1, axis=0)

        delta_e = h - east - talus
        delta_s = h - south - talus

        transfer_e = np.clip(delta_e, 0, None) * 0.25
        transfer_s = np.clip(delta_s, 0, None) * 0.25

        h -= transfer_e + transfer_s
        h += np.roll(transfer_e, 1, axis=1) + np.roll(transfer_s, 1, axis=0)

        h = np.minimum(h, np.maximum(np.roll(h, 1, axis=1), np.roll(h, 1, axis=0)))

    return h


def add_surface_detail(heightmap, seed=0, strength=0.028):
    h = heightmap.copy()
    height, width = h.shape
    y = np.linspace(-1.0, 1.0, height)[:, None]
    x = np.linspace(-1.0, 1.0, width)[None, :]
    phase = (seed % 19) * 0.27

    micro = (np.sin(24.1 * x + 18.7 * y + phase * 1.9) * np.cos(11.4 * x - 10.3 * y - phase * 0.8) * 0.014
           + np.sin(16.2 * x - 13.7 * y + phase * 1.2) * np.cos(9.7 * x + 20.5 * y - phase * 1.4) * 0.008)
    ridge_detail = np.sin(8.4 * x + 6.9 * y + phase * 1.5) * 0.009
    micro += ridge_detail * np.clip(h * 1.4, 0.0, 1.0)

    h += micro * np.clip(np.abs(h - 0.45) + 0.2, 0.2, 1.0) * strength
    return h


def carve_rivers(heightmap, seed=0, strength=0.045):
    h = heightmap.copy()
    height, width = h.shape
    y = np.linspace(0.0, 1.0, height)[:, None]
    x = np.linspace(0.0, 1.0, width)[None, :]

    phase = (seed % 29) * 0.23
    main_river_x = 0.46 + 0.24 * np.sin(2.0 * np.pi * y * 1.45 + phase)
    tributary_x = 0.68 + 0.16 * np.sin(2.0 * np.pi * y * 1.05 - phase * 0.9)
    braided_x = 0.25 + 0.14 * np.sin(4.4 * y + phase * 1.05)

    main_channel = np.exp(-((x - main_river_x) ** 2) * 160.0) * np.exp(-((y - 0.14) ** 2) * 12.0)
    tributary_channel = np.exp(-((x - tributary_x) ** 2) * 180.0) * np.exp(-((y - 0.60) ** 2) * 18.0)
    braided_channel = np.exp(-((x - braided_x) ** 2) * 180.0) * np.exp(-((y - 0.78) ** 2) * 10.0)

    river_depth = main_channel + tributary_channel * 0.7 + braided_channel * 0.5
    river_cuts = np.clip(river_depth - 0.02, 0.0, 1.0) * strength * np.exp(-((h + 0.08) ** 2) * 6.0)

    h -= river_cuts
    h = np.minimum(h, np.roll(h, 1, axis=0))
    h = np.minimum(h, np.roll(h, 1, axis=1))
    return h


def add_volcanic_features(heightmap, count=10, height_strength=0.18, seed=0):
    h = heightmap.copy()
    height, width = h.shape
    y = np.linspace(0.0, 1.0, height)[:, None]
    x = np.linspace(0.0, 1.0, width)[None, :]
    plate_line = np.sin(3.4 * x + 2.1 * y + (seed % 13) * 0.23) * np.cos(2.7 * x - 4.1 * y + (seed % 7) * 0.31)
    boundary_map = np.abs(np.sin(plate_line * 6.0))

    positions = [
        (0.22, 0.18),
        (0.30, 0.74),
        (0.48, 0.42),
        (0.62, 0.82),
        (0.71, 0.28),
        (0.78, 0.60),
        (0.35, 0.52),
        (0.58, 0.30),
        (0.18, 0.58),
        (0.84, 0.20),
    ]

    for i in range(count):
        frac_y, frac_x = positions[i % len(positions)]
        cy = frac_y * (height - 1) + ((seed % 7) * 2)
        cx = frac_x * (width - 1) + (((seed + 5) % 7) * 3)
        radius = min(height, width) * (0.035 + 0.01 * ((i + seed) % 4))
        dist = np.hypot(np.arange(height)[:, None] - cy, np.arange(width) - cx)
        cone = np.clip(1.0 - dist / radius, 0.0, 1.0)
        h += height_strength * cone**2 * (0.9 + 0.15 * np.cos((i + seed) * 1.3))

        flow = np.exp(-((x - frac_x) ** 2 + (y - frac_y) ** 2) * 40.0) * 0.03
        h -= flow * (1.0 - np.clip(boundary_map, 0.0, 1.0))

    return h


def create_planet_surface_map(size=512, seed=42):
    base = deterministic_base_terrain((size, size), seed=seed)
    base = normalize(base)
    tectonic = apply_plate_tectonics(base, strength=0.18, plates=8, seed=seed)
    volcanic = add_volcanic_features(tectonic, count=15, height_strength=0.15, seed=seed + 1)
    rivered = carve_rivers(volcanic, seed=seed + 2, strength=0.05)
    eroded = simulate_erosion(rivered, iterations=14, talus=0.012)
    detailed = add_surface_detail(eroded, seed=seed + 3, strength=0.028)
    shadowed = apply_ridge_shadows(detailed, light_angle=np.pi * 0.42, strength=0.035)
    sharpened = apply_sharpening(shadowed, strength=0.18)
    contrasted = apply_contrast_boost(sharpened, factor=1.18)
    final = normalize(contrasted)
    return final


def apply_sharpening(heightmap, strength=0.28):
    blurred = (
        heightmap * 4
        + np.roll(heightmap, 1, axis=0)
        + np.roll(heightmap, -1, axis=0)
        + np.roll(heightmap, 1, axis=1)
        + np.roll(heightmap, -1, axis=1)
    ) / 8.0
    detail = heightmap - blurred
    sharpened = heightmap + detail * strength
    return np.clip(sharpened, 0.0, 1.0)


def apply_contrast_boost(heightmap, factor=1.18):
    mean = 0.5
    return np.clip((heightmap - mean) * factor + mean, 0.0, 1.0)


def apply_ridge_shadows(heightmap, light_angle=np.pi * 0.42, strength=0.035):
    dy, dx = np.gradient(heightmap)
    lx = np.cos(light_angle)
    ly = np.sin(light_angle)
    illumination = dx * lx + dy * ly
    dark = np.clip(-illumination, 0.0, 1.0) * strength
    bright = np.clip(illumination, 0.0, 1.0) * (strength * 0.25)
    return heightmap - dark + bright


def _hex_to_rgb(hex_string):
    hex_string = hex_string.lstrip("#")
    return tuple(int(hex_string[i:i+2], 16) for i in (0, 2, 4))


def create_planet_colormap():
    colors = [
        (0.00, "#021423"),
        (0.08, "#0f3a66"),
        (0.18, "#1f6db3"),
        (0.28, "#70a6db"),
        (0.36, "#cfdde8"),
        (0.42, "#e6d5b1"),
        (0.50, "#8aa85c"),
        (0.62, "#5f7a42"),
        (0.72, "#7f6541"),
        (0.82, "#b18d5f"),
        (0.90, "#d9c9b4"),
        (1.00, "#f6f6f3"),
    ]
    positions = np.array([position for position, _ in colors], dtype=float)
    palette = np.array([_hex_to_rgb(color) for _, color in colors], dtype=np.uint8)
    return positions, palette


def plot_surface_map(heightmap, filename="planet_surface_map.png"):
    positions, palette = create_planet_colormap()
    flat = heightmap.flatten()
    r = np.interp(flat, positions, palette[:, 0]).astype(np.uint8)
    g = np.interp(flat, positions, palette[:, 1]).astype(np.uint8)
    b = np.interp(flat, positions, palette[:, 2]).astype(np.uint8)
    image_array = np.stack((r, g, b), axis=-1).reshape(heightmap.shape[0], heightmap.shape[1], 3)
    image = Image.fromarray(image_array, mode="RGB")
    image.save(filename)


if __name__ == "__main__":
    map_size = 4096
    seed = 2026
    surface_map = create_planet_surface_map(size=map_size, seed=seed)
    plot_surface_map(surface_map)
    print(f"Generated planetary surface map of size {map_size}x{map_size} and saved to planet_surface_map.png")
