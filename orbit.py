import numpy as np
from matplotlib.animation import FuncAnimation
import math

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
dt = 2 * 60 * 60  # 2 hours in seconds

# Calculate the orbital period (T) using Kepler's third law
T = 2 * np.pi * np.sqrt(r**3 / (G * M))  # Orbital period in seconds
num_steps = int(T / dt)  # Number of steps for one complete orbit

# Lists to store positions
x_positions = []
y_positions = []

# Simulation loop
x, y = r, 0
vx, vy = 0, v

for _ in range(num_steps):  # Simulate for one complete orbit
    r = np.sqrt(x**2 + y**2)
    ax = -G * M * x / r**3
    ay = -G * M * y / r**3
    vx += ax * dt
    vy += ay * dt
    x += vx * dt
    y += vy * dt
    x_positions.append(x)
    y_positions.append(y)

# Scale position data to 1% of original
#x_positions = [x * 0.0001 for x in x_positions]
#y_positions = [y * 0.0001 for y in y_positions]

# Animation
fig, ax = plt.subplots()
ax.set_aspect('equal', adjustable='datalim')
ax.plot(0, 0, 'yo', label='Star')  # Star at the center
line, = ax.plot([], [], 'b-', label='Orbit')
planet, = ax.plot([], [], 'ro', label='Planet')

# Set axis limits dynamically and center on the star
x_min, x_max = min(x_positions), max(x_positions)
y_min, y_max = min(y_positions), max(y_positions)
padding = 0.5 * max(x_max - x_min, y_max - y_min)  # Add 50% padding
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
    
    # Calculate the angle of the planet relative to the star
    angle = math.degrees(math.atan2(y_positions[frame], x_positions[frame]))
    
    # Calculate the velocity magnitude
    velocity = np.sqrt(vx**2 + vy**2)
    
    print(f"Frame {frame}: Planet angle = {angle:.2f} degrees, Velocity = {velocity:.2f} m/s")
    
    return line, planet

ani = FuncAnimation(fig, update, frames=len(x_positions), init_func=init, blit=True, interval=20)
plt.legend()
plt.show()

