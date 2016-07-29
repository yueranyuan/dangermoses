GAME_WIDTH = 1200
GAME_HEIGHT = 800
MAP_WIDTH = 30 -- Number of tiles the map is wide. Crops.
MAP_HEIGHT = 30 -- Numer of tiles the map is high.
MAP_SCALE = 26 -- Number of pixels per tile.
AI_SPEED = 15.0
HATER_PER_MEMBER = 1
POWERUP_TRAY_WIDTH = 90
MAP_DATA = {
    bg="grafix/map_bg.png",
    type="grafix/map_type.png",
    district="grafix/map_district.png",
    csv=nil --"map.csv"
}

SHITTINESS_BASE = 30  -- the shittiness of the first committee
SHITTINESS_SLOPE = 5  -- how much the shittiness increase with each committee level
SUPPORTER_CHANCE = 0.35  -- percentage of people who are supporters
PURE_HATER_PERCENTAGE = 0.33  -- percentage of haters who are pure haters
FLOOR_POWERUP_DISTRIBUTION = {goodpublcty3=2, strongarm3=2, goodpublcty2=3, strongarm2=3, shutdown2=3, lackey2=5, lackey=30 }
