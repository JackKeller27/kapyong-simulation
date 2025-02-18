import pandas as pd
import numpy as np

# Load elevation data
df = pd.read_csv("hill_677_elevation_grid.csv")

# Sort by latitude (descending) and then longitude (ascending)
df = df.sort_values(by=["latitude", "longitude"], ascending=[False, True])

# Convert to 2D grid
lat_vals = sorted(df["latitude"].unique(), reverse=True)
lon_vals = sorted(df["longitude"].unique())

lat_idx = {lat: i for i, lat in enumerate(lat_vals)}
lon_idx = {lon: i for i, lon in enumerate(lon_vals)}

# Initialize the grid
grid = np.full((len(lat_vals), len(lon_vals)), np.nan)

# Populate the grid with elevation values
for _, row in df.iterrows():
    i, j = lat_idx[row["latitude"]], lon_idx[row["longitude"]]
    grid[i, j] = row["elevation"]

# Compute gradient using finite differences at each point
dy, dx = 111000 * (lat_vals[0] - lat_vals[1]), 111000 * (lon_vals[1] - lon_vals[0])  # Convert to meters

# Gradient in longitude (x direction) using central differences for interior points
grad_x = np.zeros_like(grid)
grad_x[:, 1:-1] = (grid[:, 2:] - grid[:, :-2]) / (2 * dx)  # Central difference in x direction

# Gradient in latitude (y direction) using central differences for interior points
grad_y = np.zeros_like(grid)
grad_y[1:-1, :] = (grid[2:, :] - grid[:-2, :]) / (2 * dy)  # Central difference in y direction

# Compute the gradient magnitude at each point
gradient_magnitude = np.sqrt(grad_x**2 + grad_y**2)

# Save the gradient data to a new CSV file
gradient_data = []

# Collect gradient data for each latitude and longitude point
for i in range(len(lat_vals)):
    for j in range(len(lon_vals)):
        if not np.isnan(gradient_magnitude[i, j]):
            gradient_data.append([lat_vals[i], lon_vals[j], gradient_magnitude[i, j]])

# Save the data to a DataFrame
gradient_df = pd.DataFrame(gradient_data, columns=["latitude", "longitude", "gradient"])

# Export the data to CSV
gradient_df.to_csv("hill_677_gradients_per_point.csv", index=False)

print("Gradient data saved to hill_677_gradients_per_point.csv")
