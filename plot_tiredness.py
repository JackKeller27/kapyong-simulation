import numpy as np
import matplotlib.pyplot as plt

def update_un_tiredness(ticks, steepness_multiplier, weapons_multiplier, un_baseline_tiredness, un_initial_tiredness):
    """Simulates the NetLogo update-un-tiredness function."""
    decay_rate = 0.005 - 0.004 * (0.6 * steepness_multiplier + 0.4 * weapons_multiplier)
    t0 = 600

    tiredness = un_baseline_tiredness + (un_initial_tiredness - un_baseline_tiredness) / (1 + np.exp(decay_rate * (ticks - t0)))
    un_tiredness_multiplier = tiredness / 100

    return un_tiredness_multiplier

# Example parameter values
un_baseline_tiredness = 20
un_initial_tiredness = 100
steepness_multiplier = 0.5
weapons_multiplier = 0.5

# Generate ticks values
ticks_values = np.arange(0, 1500, 1)

# Calculate un-tiredness multiplier for each tick
un_tiredness_multipliers = [update_un_tiredness(tick, steepness_multiplier, weapons_multiplier, un_baseline_tiredness, un_initial_tiredness) for tick in ticks_values]

# Plot the results
plt.figure(figsize=(10, 6))
plt.plot(ticks_values, un_tiredness_multipliers)
plt.title("Un-tiredness Multiplier over Ticks")
plt.xlabel("Ticks")
plt.ylabel("Un-tiredness Multiplier")
plt.grid(True)
plt.show()

#Plotting for varying steepness multipliers.
steepness_multipliers = [0, 0.25, 0.5, 0.75, 1]
plt.figure(figsize=(12, 8))
for steepness in steepness_multipliers:
    un_tiredness_multipliers = [update_un_tiredness(tick, steepness, weapons_multiplier, un_baseline_tiredness, un_initial_tiredness) for tick in ticks_values]
    plt.plot(ticks_values, un_tiredness_multipliers, label=f"Steepness: {steepness}")

plt.title("Un-tiredness Multiplier over Ticks (Varying Steepness)")
plt.xlabel("Ticks")
plt.ylabel("Un-tiredness Multiplier")
plt.grid(True)
plt.legend()
plt.show()

#Plotting for varying weapons multipliers.
weapons_multipliers = [0, 0.25, 0.5, 0.75, 1]
plt.figure(figsize=(12, 8))
for weapons in weapons_multipliers:
    un_tiredness_multipliers = [update_un_tiredness(tick, steepness_multiplier, weapons, un_baseline_tiredness, un_initial_tiredness) for tick in ticks_values]
    plt.plot(ticks_values, un_tiredness_multipliers, label=f"Weapons: {weapons}")

plt.title("Un-Tiredness Multiplier over Ticks (Varying Weapons)")
plt.xlabel("Ticks")
plt.ylabel("Un-Tiredness Multiplier")
plt.grid(True)
plt.legend()
plt.show()