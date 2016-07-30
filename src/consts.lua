GAME_WIDTH = 1200
GAME_HEIGHT = 800
MAP_WIDTH = 35 -- Number of tiles the map is wide. Crops.
MAP_HEIGHT = 30 -- Numer of tiles the map is high.
MAP_SCALE = 25 -- Number of pixels per tile.
AI_SPEED = 15.0
HATER_PER_MEMBER = 1
POWERUP_TRAY_WIDTH = 80
IS_TUTORIAL = false
SOUND_ON = false
REGULAR_MAP_DATA = {
    bg="grafix/map_bg.png",
    type="grafix/map_type.png",
    district="grafix/map_district.png",
    committees={"park", "tenament", "road", "washington", "adams", "jefferson"},
    csv=nil --"map.csv"
}
TUTORIAL_MAP_DATA = {
    bg="grafix/map_bg.png",
    type="grafix/map_type.png",
    district="grafix/map_district.png",
    committees={"park", "tenament", "road"},
    csv=nil --"map.csv"
}
MAP_DATA = REGULAR_MAP_DATA

SHITTINESS_BASE = 1  -- the shittiness of the first committee
SHITTINESS_SLOPE = 16  -- how much the shittiness increase with each committee level
SUPPORTER_CHANCE = 0.3  -- percentage of people who are supporters
PURE_HATER_PERCENTAGE = 0.15  -- percentage of haters who are pure haters
FLOOR_POWERUP_DISTRIBUTION = {
    goodpublcty3=1, goodpublcty2=2,
    strongarm2=2, strongarm3=1,
    shutdown3=1, shutdown2=2,
    lackey3=2, lackey2=3, lackey=0,
    mislabel3=1, mislabel2=1,
    appeal=3
  }
