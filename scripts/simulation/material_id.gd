class_name MaterialId
extends RefCounted

const EMPTY := 0

static func key(id: int) -> String:
	return ElementDB.get_key_for_id(id)

static func id(key: String) -> int:
	return ElementDB.get_id(key)

static func is_empty(mat: int) -> bool:
	return mat == EMPTY

static func is_solid(mat: int) -> bool:
	var k := key(mat)
	return ElementDB.get_element_class(k) == "SOLID"

static func is_powder(mat: int) -> bool:
	return ElementDB.get_element_class(key(mat)) == "POWDER"

static func is_liquid(mat: int) -> bool:
	return ElementDB.get_element_class(key(mat)) == "LIQUID"

static func is_gas(mat: int) -> bool:
	return ElementDB.get_element_class(key(mat)) == "GAS"

static func is_energy(mat: int) -> bool:
	return ElementDB.get_element_class(key(mat)) == "ENERGY"

static func density(mat: int) -> int:
	return ElementDB.get_density(key(mat))

static func is_flammable(mat: int) -> bool:
	return ElementDB.is_flammable(key(mat))
