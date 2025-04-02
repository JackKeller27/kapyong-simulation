import numpy as np
import matplotlib.pyplot as plt

def tiredness(steepness_multiplier, weapons_multiplier, ticks):
    sqrt_steep = max(np.sqrt(steepness_multiplier), 0.3)
    sqrt_weapons = max(np.sqrt(weapons_multiplier), 0.3)
    interaction = sqrt_steep * sqrt_weapons
    
    un_baseline_tiredness = 0.05 + 0.1 * interaction
    un_initial_tiredness = min(0.1 + 0.9 * interaction, 1.0)
    
    # Adjusted decay rate: now decreases as steepness and weapons increase
    decay_rate = 0.01 #- 0.001 * (steepness_multiplier + weapons_multiplier)
    t0 = 600
    
    tiredness = un_baseline_tiredness + (un_initial_tiredness - un_baseline_tiredness) / (1 + np.exp(decay_rate * (ticks - t0)))
    return tiredness

def plot_tiredness():
    combinations = [
        #(1.25, 1.0),
        (1.0, 1.0),
        (0.75, 0.75),
        (0.5, 0.5),
        (0.25, 0.25),
    ]
    time_steps = np.linspace(0, 1200, 300)  # Simulate over time
    hours_conversion = 3600 / 5  # 1 hour in ticks
    time_hours = time_steps / hours_conversion  # Convert ticks to hours
    
    plt.figure(figsize=(10, 6))
    
    for steepness, weapons in combinations:
        tiredness_values = [tiredness(steepness, weapons, t) for t in time_steps]
        plt.plot(time_hours, tiredness_values, label=f"Steepness={int(steepness * 100)}%, Weapons={int(weapons * 100)}%")
    
    plt.xlabel("Time (hours)")
    plt.ylabel("Fatigue")
    plt.title("Soldier Fatigue Given Steepness and Number of Weapons")
    plt.legend()
    plt.grid()
    plt.show()

plot_tiredness()
