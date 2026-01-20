class_name AreaScaler
extends RefCounted
## Utility for area-based stat scaling
## Stats increase Area, visual/collision radius scales as sqrt(area)


## Calculate new radius given a percentage area bonus
## Formula: NewRadius = BaseRadius * sqrt(1.0 + percent_area_bonus)
## Example: 50% area bonus (0.5) = ~22.5% radius increase
static func scale_radius_by_area(base_radius: float, area_percent_bonus: float) -> float:
	return base_radius * sqrt(1.0 + area_percent_bonus)


## Get the area multiplier from a percentage bonus
## Example: 0.5 (50% bonus) returns 1.5 (150% of original area)
static func get_area_multiplier(area_percent_bonus: float) -> float:
	return 1.0 + area_percent_bonus


## Calculate area from radius (for display purposes)
static func radius_to_area(radius: float) -> float:
	return PI * radius * radius


## Calculate radius from area (inverse operation)
static func area_to_radius(area: float) -> float:
	return sqrt(area / PI)


## Get the percentage increase in radius from a percentage increase in area
## Useful for UI tooltips: "50% increased area = 22.5% increased radius"
static func area_bonus_to_radius_bonus(area_percent_bonus: float) -> float:
	return sqrt(1.0 + area_percent_bonus) - 1.0


## Get the percentage increase in area from a percentage increase in radius
## Inverse of area_bonus_to_radius_bonus
static func radius_bonus_to_area_bonus(radius_percent_bonus: float) -> float:
	var multiplier := 1.0 + radius_percent_bonus
	return (multiplier * multiplier) - 1.0
