extends RefCounted
## how map select groups and describes each place. presentation only: ids come from the live
## catalog, and a map missing here still gets a group from its catalog kind and capabilities.

const GROUPS := ["bhop", "swing", "experiment"]
const GROUP_TITLES := {"bhop": "Bhop courses", "swing": "Swing courses", "experiment": "Experiments"}
const GROUP_KICKERS := {"bhop": "Bhop course", "swing": "Swing course", "experiment": "Experiment"}
const GROUP_NOTES := {
	"bhop": "Hop, strafe and carry speed from spawn to finish.",
	"swing": "Rope courses: hold to swing, release to coast, hop between transfers.",
	"experiment": "Separate maps with experimental rules. The main maps keep their movement."}

## per place: its group, a card line short enough for a 1280x720 card, and the fuller sentence
## the preview shows. written for the player; the catalog's own theme strings stay untouched.
const PLACES := {
	"breakwater": {"group": "bhop", "line": "Container port at dusk", "about": "A container port at dusk: long hop lines between the stacks."},
	"whiteout-relay": {"group": "bhop", "line": "Snowy radar station", "about": "A snowy radar station on the heights."},
	"sunken-court": {"group": "bhop", "line": "Sunlit overgrown ruin", "about": "A sunlit, overgrown ruin of courts and arches."},
	"rainline": {"group": "bhop", "line": "Rainy rooftop district", "about": "A rainy rooftop district."},
	"night-shift": {"group": "bhop", "line": "Night transit works", "about": "Transit works after dark."},
	"practice": {"group": "bhop", "line": "Open practice yard", "about": "An open yard for speed, strafes and gap practice."},
	"overflow": {"group": "bhop", "line": "Dam top and spillways", "about": "A dam-top run through spillways and service decks."},
	"saltglass": {"group": "bhop", "line": "Low exits, salt pans", "about": "Low exits, climbing salt pans and outside lines."},
	"saltglass-seaward": {"group": "bhop", "line": "Seaward receiver line", "about": "Saltglass with a visible seaward receiver; the original stays as it was."},
	"sluice-six": {"group": "bhop", "line": "Spill tower and piers", "about": "Tidal settling decks, a pier rhythm and the spill tower."},
	"outer-reach": {"group": "bhop", "line": "Long estuary corridors", "about": "The outer estuary: a long quay, sustained air corridors and a tidal pump."},
	"tether-yard": {"group": "swing", "line": "Swing across the yard", "about": "Hold, swing and release across the transfer yard."},
	"viaduct": {"group": "swing", "line": "Arcs under the bridge", "about": "Link Arc swings beneath the maintenance bridge."},
	"gantry": {"group": "swing", "line": "Crane slot hop lines", "about": "Build a hop line and carry it through the crane slots."},
	"gantry-chain": {"group": "swing", "line": "Three Arc transfers", "about": "A longer Gantry: the dispatch hops run straight into a third Arc transfer."},
	"foundry": {"group": "swing", "line": "High gallery or shaft", "about": "Take the high gallery, or commit to the shaft crossing."},
	"experiment": {"group": "experiment", "line": "Not a course", "about": "Try slide, wall jump and grapple. Records keep each loadout apart."},
	"through-line": {"group": "experiment", "line": "Rise through the fork", "about": "Build speed, rise through the fork and land running."},
	"mail-run": {"group": "experiment", "line": "Steer the post", "about": "Hold the hop. Throw the envelope and steer it to its box."},
	"plan-yard": {"group": "experiment", "line": "Place a line, run it", "about": "Plan the pieces untimed, then run the line you placed."},
}

static func group(id: String, entry: Dictionary, capabilities: Dictionary = {}) -> String:
	if PLACES.has(id):
		return str(PLACES[id].group)
	var kind := str(entry.get("kind", ""))
	if kind in ["experiment", "lab"]:
		return "swing" if kind == "experiment" and bool(entry.get("grapple", capabilities.get("grapple", false))) else "experiment"
	return "bhop"

static func line(id: String, entry: Dictionary) -> String:
	if PLACES.has(id):
		return str(PLACES[id].line)
	var theme := str(entry.get("theme", ""))
	return "Not a course · " + theme if str(entry.get("kind", "")) == "lab" else theme

## the preview's sentence: the fuller description, else the card line.
static func about(id: String, entry: Dictionary) -> String:
	if PLACES.has(id):
		return str(PLACES[id].get("about", PLACES[id].line))
	return line(id, entry)
