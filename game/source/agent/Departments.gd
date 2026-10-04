extends RefCounted

# Departments organise the base: every building belongs to one (its capability; Human
# Approval sits with Command) and every character to its home building's. The map is a
# 3x3 grid of districts split by streets. Mirrors DEPARTMENTS/DISTRICTS in adapter/src/layout.ts.
#
#   Research   | Commons (Rally Point) | Engineering
#   Research   | Command + Approval    | Engineering
#   Knowledge  | Knowledge             | Commons (Repair Bay)

const ORDER = ["command", "research", "code", "knowledge", "meeting"]
const NAMES = {"command": "Command", "research": "Research", "code": "Engineering", "knowledge": "Knowledge", "meeting": "Commons"}
const COLORS = {
	"command": Color("#b48cff"), "research": Color("#4fb3ff"), "code": Color("#ff9940"),
	"knowledge": Color("#5fd98a"), "meeting": Color("#ff7fae"),
}
const WORK = {
	"command": "Plans missions; you approve risky steps here",
	"research": "Web search, news and sources",
	"code": "Code, data and calculations",
	"knowledge": "Notes, analysis and writing",
	"meeting": "Shared spaces: meetings, waiting, repairs",
}
const DISTRICTS = [
	["research", "meeting", "code"],
	["research", "command", "code"],
	["knowledge", "knowledge", "meeting"],
]
const STREETS = [11.0, 21.0]  # x and z of the streets between districts
const CELL = 10.0


static func of(capability: String) -> String:
	return "command" if capability == "approval" else capability


static func of_building(layout: Dictionary, building_id: String) -> String:
	for b in layout.get("buildings", []):
		if b["id"] == building_id:
			return of(b["capability"])
	return "command"


static func cell_centre(col: int, row: int) -> Vector3:
	return Vector3(6.0 + col * CELL, 0, 6.0 + row * CELL)


static func centre(dept: String) -> Vector3:
	var sum = Vector3.ZERO
	var n = 0
	for r in 3:
		for c in 3:
			if DISTRICTS[r][c] == dept:
				sum += cell_centre(c, r)
				n += 1
	return sum / max(1, n)
