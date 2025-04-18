import numpy as np
from matplotlib.animation import FuncAnimation

import matplotlib.pyplot as plt

# Constants
G = 6.67430e-11  # Gravitational constant, m^3 kg^-1 s^-2
M = 1.989e30     # Mass of the star (e.g., the Sun), kg
AU = 1.496e11    # Astronomical unit, m

# Initial conditions
r = AU  # Initial distance from the star, m
v = 30000  # Initial velocity, m/s
theta = 0  # Initial angle, radians

# Time step
dt = 60 * 60  # 1 hour in seconds

# Lists to store positions
x_positions = []
y_positions = []

# Simulation loop
x, y = r, 0
vx, vy = 0, v

for _ in range(1000):  # Simulate for 1000 steps
    r = np.sqrt(x**2 + y**2)
    ax = -G * M * x / r**3
    ay = -G * M * y / r**3
    vx += ax * dt
    vy += ay * dt
    x += vx * dt
    y += vy * dt
    x_positions.append(x)
    y_positions.append(y)

# Animation
fig, ax = plt.subplots()
ax.set_aspect('equal', adjustable='datalim')
ax.plot(0, 0, 'yo', label='Star')  # Star at the center
line, = ax.plot([], [], 'b-', label='Orbit')
planet, = ax.plot([], [], 'ro', label='Planet')

# Set axis limits dynamically and center on the star
x_min, x_max = min(x_positions), max(x_positions)
y_min, y_max = min(y_positions), max(y_positions)
padding = 0.1 * max(x_max - x_min, y_max - y_min)  # Add 10% padding
x_range = max(abs(x_min), abs(x_max)) + padding
y_range = max(abs(y_min), abs(y_max)) + padding
ax.set_xlim(-x_range, x_range)
ax.set_ylim(-y_range, y_range)

def init():
    line.set_data([], [])
    planet.set_data([], [])
    return line, planet

def update(frame):
    line.set_data(x_positions[:frame], y_positions[:frame])
    planet.set_data(x_positions[frame], y_positions[frame])
    print(" x:", x_positions[frame], "y:", y_positions[frame])
    return line, planet

ani = FuncAnimation(fig, update, frames=len(x_positions), init_func=init, blit=True, interval=20)
plt.legend()
plt.show()

