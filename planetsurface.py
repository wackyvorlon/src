import numpy as np
import matplotlib.pyplot as plt


def random_noise(shape, scale=1.0, seed=None):
    rng = np.random.default_rng(seed)
    return rng.standard_normal(shape) * scale


def fractal_noise(shape, octaves=6, persistence=0.5, lacunarity=2.0, seed=None):
    height, width = shape
    noise = np.zeros(shape, dtype=float)
    amplitude = 1.0
    frequency = 1.0
    total_amplitude = 0.0

    for _ in range(octaves):
        noise += amplitude * random_noise(shape, seed=seed)
        total_amplitude += amplitude
        amplitude *= persistence
        frequency *= lacunarity

    return noise / total_amplitude


def normalize(heightmap):
    min_h = np.min(heightmap)
    max_h = np.max(heightmap)
    return (heightmap - min_h) / (max_h - min_h + 1e-12)


def apply_plate_tectonics(heightmap, strength=0.12, plates=6, seed=None):
    rng = np.random.default_rng(seed)
    height, width = heightmap.shape
    plate_seed = rng.integers(0, 10**6, size=plates)
    plate_map = np.zeros_like(heightmap)
    for i in range(plates):
        center_y = rng.integers(0, height)
        center_x = rng.integers(0, width)
        plate = np.hypot(np.arange(height)[:, None] - center_y, np.arange(width) - center_x)
        plate_map += np.tanh(plate / (0.4 * max(height, width))) * (rng.uniform(-1, 1) * strength)
    return heightmap + plate_map


def simulate_erosion(heightmap, iterations=1000, talus=0.01):
    h = heightmap.copy()
    height, width = h.shape
    for _ in range(iterations):
        y = np.random.randint(0, height)
        x = np.random.randint(0, width)
        current = h[y, x]
        neighbors = []
        if x > 0:
            neighbors.append((y, x - 1))
        if x < width - 1:
            neighbors.append((y, x + 1))
        if y > 0:
            neighbors.append((y - 1, x))
        if y < height - 1:
            neighbors.append((y + 1, x))
        if not neighbors:
            continue
        ny, nx = neighbors[np.argmin([h[yy, xx] for yy, xx in neighbors])]
        delta = current - h[ny, nx]
        if delta > talus:
            transfer = (delta - talus) * 0.5
            h[y, x] -= transfer
            h[ny, nx] += transfer
    return h


def add_volcanic_features(heightmap, count=10, height_strength=0.2, seed=None):
    rng = np.random.default_rng(seed)
    h = heightmap.copy()
    height, width = h.shape
    for _ in range(count):
        cy = rng.integers(0, height)
        cx = rng.integers(0, width)
        radius = rng.integers(max(5, min(height, width) // 50), max(10, min(height, width) // 20))
        dist = np.hypot(np.arange(height)[:, None] - cy, np.arange(width) - cx)
        cone = np.clip(1 - dist / radius, 0, 1)
        h += height_strength * cone**2
    return h


def create_planet_surface_map(size=512, seed=42):
    base = fractal_noise((size, size), octaves=7, persistence=0.55, seed=seed)
    base = normalize(base)
    tectonic = apply_plate_tectonics(base, strength=0.18, plates=8, seed=seed)
    volcanic = add_volcanic_features(tectonic, count=15, height_strength=0.15, seed=seed + 1)
    eroded = simulate_erosion(volcanic, iterations=size * size // 20, talus=0.012)
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
