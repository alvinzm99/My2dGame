class_name SpatialQueries
extends RefCounted

static func survivor_at(survivors: Array[Dictionary], pos: Vector2) -> int:
	for i in survivors.size():
		if survivors[i]["pos"].distance_to(pos) <= 28.0:
			return i
	return -1

static func resource_at(resources: Array[Dictionary], pos: Vector2) -> int:
	for i in resources.size():
		if resources[i]["pos"].distance_to(pos) <= 34.0:
			return i
	return -1

static func zombie_at(zombies: Array[Dictionary], pos: Vector2) -> int:
	for i in zombies.size():
		if zombies[i]["pos"].distance_to(pos) <= 30.0:
			return i
	return -1

static func building_at(buildings: Array[Dictionary], pos: Vector2) -> int:
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		var half: Vector2 = b["size"] * 0.55
		if Rect2(b["pos"] - half, half * 2.0).has_point(pos):
			return i
	return -1

static func nearest_zombie(zombies: Array[Dictionary], pos: Vector2, max_range: float) -> int:
	var best := -1
	var best_distance := max_range
	for i in zombies.size():
		var d := pos.distance_to(zombies[i]["pos"])
		if d < best_distance:
			best = i
			best_distance = d
	return best

static func nearest_damaged_building(buildings: Array[Dictionary], pos: Vector2, max_range: float) -> int:
	var best := -1
	var best_distance := max_range
	for i in buildings.size():
		if float(buildings[i]["hp"]) >= float(buildings[i]["max_hp"]):
			continue
		var d := pos.distance_to(buildings[i]["pos"])
		if d < best_distance:
			best = i
			best_distance = d
	return best
