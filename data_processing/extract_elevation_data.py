import numpy as np
import geopandas as gpd
import shapely.geometry as geom
from pykml import parser
import requests

# Resolution parameters
HIGH_RES_SPACING = 0.00033 # 30 x 30 patches
LOW_RES_SPACING = 0.0005 # 20 x 20 patches

# Map parameters
MAP_WIDTH = 2.25  # in miles
MAP_HEIGHT = 2.25  # in miles

# Conversion factor (1 mile in lat/lon degrees)
MILE_TO_DEGREES = 0.01449275362

# Hill 677 center coordinates (from Google Earth)
center_lat = 37 + (52 / 60) + (54.45 / 3600)  # Convert from degrees to decimal
center_lon = 127 + (28 / 60) + (46.68 / 3600)  # Convert from degrees to decimal

# Compute half-width and half-height in degrees
half_width = (MAP_WIDTH / 2) * MILE_TO_DEGREES
half_height = (MAP_HEIGHT / 2) * MILE_TO_DEGREES

# Define the bounding square
square_coords = [
    (center_lon - half_width, center_lat - half_height),  # Bottom-left
    (center_lon + half_width, center_lat - half_height),  # Bottom-right
    (center_lon + half_width, center_lat + half_height),  # Top-right
    (center_lon - half_width, center_lat + half_height),  # Top-left
    (center_lon - half_width, center_lat - half_height)   # Close the polygon
]

# Create the square polygon around hill 677
hill_677_poly = geom.Polygon(square_coords)

# # Print the square's bounds
# print("Bounding Square Coordinates:")
# for coord in square_coords:
#     print(f"Latitude: {coord[1]}, Longitude: {coord[0]}")

### NOTE below code is to get polygon bounds based on exported Google Earth data
# # Load KML file
# kml_file = "data/hill_677_data.kml"
# with open(kml_file, "r", encoding="utf-8") as f:
#     root = parser.parse(f).getroot()

# # Find Polygon coordinates
# placemark = root.Document.Placemark
# polygon = placemark.find(".//{http://www.opengis.net/kml/2.2}Polygon")

# # Extract coordinates from KML (longitude, latitude, altitude)
# coords_text = polygon.find(".//{http://www.opengis.net/kml/2.2}coordinates").text.strip()
# boundary_coords = [tuple(map(float, c.split(","))) for c in coords_text.split()]

# # Convert to a Polygon
# polygon_geom = geom.Polygon([(lon, lat) for lon, lat, _ in boundary_coords])
###

# Generate a grid of points within the polygon
def generate_grid(polygon, spacing=HIGH_RES_SPACING):  # Adjust spacing for resolution
    min_x, min_y, max_x, max_y = polygon.bounds
    x_coords = np.arange(min_x, max_x, spacing)
    y_coords = np.arange(min_y, max_y, spacing)
    
    print(min_x, min_y, max_x, max_y)
    print(x_coords)
    print(y_coords)

    grid_points = []
    for x in x_coords:
        for y in y_coords:
            point = geom.Point(x, y)
            if polygon.contains(point):
                grid_points.append((y, x))  # Save as (latitude, longitude)
    return grid_points

grid_points = generate_grid(hill_677_poly)
print(len(grid_points))

# Fetch elevation data using Google Elevation API
API_KEY = "AIzaSyAFxzsLZdxmzVZtKWZ80xLh1xRBoMDNfM0"  # https://console.cloud.google.com/google/maps-apis/home?project=battle-of-kapyong&inv=1&invt=AbpIjA&supportedpurview=project

def get_elevation(lat, lon):
    url = f"https://maps.googleapis.com/maps/api/elevation/json?locations={lat},{lon}&key={API_KEY}"
    response = requests.get(url).json()
    if "results" in response and len(response["results"]) > 0:
        return response["results"][0]["elevation"]
    return None

# Query elevations for all points
elevation_data = [(lat, lon, get_elevation(lat, lon)) for lat, lon in grid_points]

# Save to CSV
with open("data/hill_677_elevation_data.csv", "w") as f:
    f.write("latitude,longitude,elevation\n")
    for lat, lon, elev in elevation_data:
        f.write(f"{lat},{lon},{elev}\n")

print("Elevation grid saved as data/hill_677_elevation_data.csv")
