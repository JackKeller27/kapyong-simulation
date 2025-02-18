import numpy as np
import geopandas as gpd
import shapely.geometry as geom
from pykml import parser
import requests

# Load KML file
kml_file = "hill_677_data.kml"
with open(kml_file, "r", encoding="utf-8") as f:
    root = parser.parse(f).getroot()

# Find Polygon coordinates
placemark = root.Document.Placemark
polygon = placemark.find(".//{http://www.opengis.net/kml/2.2}Polygon")

# Extract coordinates from KML (longitude, latitude, altitude)
coords_text = polygon.find(".//{http://www.opengis.net/kml/2.2}coordinates").text.strip()
boundary_coords = [tuple(map(float, c.split(","))) for c in coords_text.split()]

# Convert to a Polygon
polygon_geom = geom.Polygon([(lon, lat) for lon, lat, _ in boundary_coords])

# Generate a grid of points within the polygon
def generate_grid(polygon, spacing=0.001):  # Adjust spacing for resolution
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

grid_points = generate_grid(polygon_geom)
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
with open("hill_677_elevation_grid.csv", "w") as f:
    f.write("latitude,longitude,elevation\n")
    for lat, lon, elev in elevation_data:
        f.write(f"{lat},{lon},{elev}\n")

print("Elevation grid saved as hill_677_elevation_grid.csv")
