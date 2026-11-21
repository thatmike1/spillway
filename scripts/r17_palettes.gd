extends RefCounted
## presentation choices. none enter course, motion, scoring, recording or ghost identities.
## tops are one shell-white family, neutral to slightly cool, so each map's warm sun lands them on cream, not yellow.
const ROOT := "res://assets/look/r17/"
const MAPS := {
	"breakwater": {"top":"e0dad2", "side":"527b87", "sky":"res://assets/look/cloud-sky.png", "sun":"fff0d3", "fill":"a6bfc3", "sun_energy":0.48, "ambient":0.32, "pitch":-24.0, "yaw":-135.0, "turn":180.0, "fog":"a5c2bd"},
	"whiteout-relay": {"top":"dcd8d0", "side":"4e677d", "sky":ROOT+"whiteout-sky.png", "sun":"ffe9cb", "fill":"a7c1d9", "sun_energy":0.48, "ambient":0.32, "pitch":-26.0, "yaw":-36.2, "turn":0.0, "fog":"b2c4d1"},
	"sunken-court": {"top":"d9d5cb", "side":"8e948c", "sky":ROOT+"sunken-sky.png", "sun":"fff4df", "fill":"b7cac5", "sun_energy":0.48, "ambient":0.32, "pitch":-50.0, "yaw":35.0, "turn":0.0, "fog":"b4c7b3"},
	"rainline": {"top":"d9dcd3", "side":"435a6b", "water_value":0.8, "sky":ROOT+"rainline-sky.png", "sun":"c6d6e5", "fill":"9eb9c9", "sun_energy":0.48, "ambient":0.48, "pitch":-48.0, "yaw":-25.0, "turn":0.0, "fog":"6f8c9a"},
	"night-shift": {"top":"dedad0", "side":"3e5671", "water_value":0.5, "sky":ROOT+"night-sky.png", "sun":"b7c9e6", "fill":"849cb8", "sun_energy":0.48, "ambient":0.55, "pitch":-40.0, "yaw":40.0, "turn":0.0, "fog":"3b506c"},
	"practice": {"top":"dedbd5", "side":"586f72", "sky":ROOT+"practice-sky.png", "sun":"fff0d2", "fill":"b0c7c9", "sun_energy":0.48, "ambient":0.32, "pitch":-34.0, "yaw":-110.0, "turn":0.0, "fog":"adc5be"},
	"overflow": {"top":"e0dad0", "side":"527879", "sky":ROOT+"overflow-sky.png", "sun":"ffe2bc", "fill":"b1c6c6", "sun_energy":0.48, "ambient":0.32, "pitch":-27.0, "yaw":-120.0, "turn":0.0, "fog":"adc2b6"},
	"experiment": {"top":"e0dcd3", "side":"506475", "sky":ROOT+"lab-sky.png", "sun":"fff0d9", "fill":"b6c9d5", "sun_energy":0.65, "ambient":0.45, "pitch":-62.0, "yaw":25.0, "turn":0.0, "fog":"8d9fa8"},
}
const LANDABLE := ["pavers","asphalt","steel_ramp","tread","tread_warm","grate","hurdle","flag","architrave","stair","deck","landing","track","run","land","recovery","return","floor","lane_floor","deck_steel","walk","roof_walk","roof_metal","roof_concrete","platform","train_roof","catwalk"]
const GROUND := ["land","moss","pool_floor","snow","snow_bank","rock","plateau","cliff","pit_floor","catch","hill","terrain"]
