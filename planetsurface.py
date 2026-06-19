import numpy as np
import matplotlib.pyplot as plt


def deterministic_base_terrain(shape, seed=0):
    height, width = shape
    y = np.linspace(-1.0, 1.0, height)[:, None]
    x = np.linspace(-1.0, 1.0, width)[None, :]

    phase = (seed % 31) * 0.21
    continent = np.tanh(2.4 * (np.sin(1.85 * x + phase * 0.6) + np.cos(1.6 * y - phase * 0.9))) * 0.24
    island = np.tanh(1.9 * (np.sin(2.6 * y + phase * 0.4) + np.cos(2.1 * x - phase * 0.7))) * 0.16
    ridges = np.sin(5.8 * x + 3.7 * y + phase * 0.8) * 0.08
    mountain_brush = np.exp(-((x - 0.25) ** 2 + (y + 0.18) ** 2) * 14.0) * 0.18
    mountain_brush += np.exp(-((x + 0.4) ** 2 + (y - 0.35) ** 2) * 18.0) * 0.14
    basin = np.exp(-((x * 0.9) ** 2 + (y * 0.75) ** 2) * 3.2) * 0.22
    equator_band = np.clip(1.0 - np.abs(y) * 1.55, 0.0, 1.0) * 0.10

    river_carve = -np.exp(-((x * 1.3 - np.sin(1.7 * y + phase * 0.7) * 0.35) ** 2) * 18.0) * 0.06
    valley_arm = -np.exp(-((x * 1.05 + 0.35) ** 2 + (y * 1.2 - 0.28) ** 2) * 16.0) * 0.05

    ocean_mask = np.clip(1.05 - (np.abs(x) ** 2 * 1.1 + np.abs(y) ** 2 * 1.35), 0.0, 1.0)
    terrain = continent * 0.55 + island * 0.3 + ridges * 0.6 + basin + mountain_brush + equator_band
    terrain += river_carve + valley_arm

    base = terrain * ocean_mask + (ocean_mask * -0.08)
    return base


def normalize(heightmap):
    min_h = np.min(heightmap)
    max_h = np.max(heightmap)
    return (heightmap - min_h) / (max_h - min_h + 1e-12)


def apply_plate_tectonics(heightmap, strength=0.12, plates=6, seed=0):
    height, width = heightmap.shape
    plate_map = np.zeros_like(heightmap)
    y_coords = np.arange(height)[:, None]
    x_coords = np.arange(width)[None, :]
    max_dim = max(height, width)

    for i in range(plates):
        angle = 2 * np.pi * (i / plates) + (seed % 11) * 0.17
        radius = 0.16 + 0.07 * ((i % 3) - 1)
        cy = (0.3 + 0.4 * np.sin(angle * 0.9)) * (height - 1)
        cx = (0.3 + 0.4 * np.cos(angle * 0.9)) * (width - 1)

        plate_distance = np.hypot(y_coords - cy, x_coords - cx)
        direction = np.cos(angle) * (x_coords - cx) + np.sin(angle) * (y_coords - cy)
        boundary = np.sin(plate_distance / max_dim * 6.5 + angle) * np.cos(direction / max_dim * 5.2)
        uplift = np.tanh(boundary * 2.4) * strength * 0.9
        core = np.exp(-plate_distance ** 2 / (0.28 * max_dim) ** 2) * (0.06 + 0.03 * np.cos(angle * 1.1))
        taper = np.exp(-plate_distance / (0.30 * max_dim))

        plate_map += (uplift + core) * taper

    return heightmap + plate_map


def simulate_erosion(heightmap, iterations=16, talus=0.010):
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
    eroded = simulate_erosion(volcanic, iterations=12, talus=0.012)
    final = normalize(eroded)
    return final


def plot_surface_map(heightmap, filename="planet_surface_map.png"):
    plt.figure(figsize=(10, 10), dpi=120)
    plt.imshow(heightmap, cmap="terrain", origin="lower")
    plt.axis("off")
    plt.title("Simulated Planetary Surface")
    plt.tight_layout()
    plt.savefig(filename, bbox_inches="tight", pad_inches=0.1)
    plt.close()


if __name__ == "__main__":
    map_size = 1024
    seed = 2026
    surface_map = create_planet_surface_map(size=map_size, seed=seed)
    plot_surface_map(surface_map)
    print(f"Generated planetary surface map of size {map_size}x{map_size} and saved to planet_surface_map.png")
