#!/usr/bin/env python3
"""Validate the v5.2 Black Sea Crisis data cross references."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "WWIIHexV0" / "Data"


def load_json(name: str) -> Any:
    with (DATA / name).open(encoding="utf-8") as handle:
        return json.load(handle)


def coord_key(coord: dict[str, int]) -> str:
    return f"{coord['q']},{coord['r']}"


def main() -> int:
    scenario = load_json("black_sea_crisis_1853_scenario.json")
    regions = load_json("black_sea_crisis_1853_regions.json")
    templates = load_json("victorian_unit_templates.json")
    personas = load_json("victorian_personas.json")
    powers = load_json("victorian_powers.json")

    errors: list[str] = []

    if scenario.get("id") != "black_sea_crisis_1853":
        errors.append("scenario.id must be black_sea_crisis_1853.")
    if regions.get("scenarioId") != scenario.get("id"):
        errors.append("regions.scenarioId must match scenario.id.")
    if templates.get("schemaVersion") != 2:
        errors.append("victorian_unit_templates.schemaVersion must be 2.")

    factions = set(scenario.get("factions", []))
    turn_order = set(scenario.get("turnOrder", []))
    human_factions = set(scenario.get("humanControlledFactions", []))
    unknown_turn_factions = turn_order - factions
    unknown_human_factions = human_factions - factions
    if unknown_turn_factions:
        errors.append(f"turnOrder contains unknown factions: {sorted(unknown_turn_factions)}")
    if unknown_human_factions:
        errors.append(f"humanControlledFactions contains unknown factions: {sorted(unknown_human_factions)}")

    power_ids = {entry["id"] for entry in powers.get("powers", [])}
    missing_powers = factions - power_ids
    if missing_powers:
        errors.append(f"victorian_powers is missing factions: {sorted(missing_powers)}")

    objective_ids = [objective["id"] for objective in scenario.get("objectives", [])]
    if len(objective_ids) != len(set(objective_ids)):
        errors.append("scenario.objectives contains duplicate ids.")
    objective_id_set = set(objective_ids)

    region_ids = [region["id"] for region in regions.get("regions", [])]
    if len(region_ids) != len(set(region_ids)):
        errors.append("regions contains duplicate ids.")
    region_id_set = set(region_ids)
    region_by_id = {region["id"]: region for region in regions.get("regions", [])}

    tiles = scenario.get("map", {}).get("tiles", [])
    tile_keys = [f"{tile['q']},{tile['r']}" for tile in tiles]
    if len(tile_keys) != len(set(tile_keys)):
        errors.append("scenario.map.tiles contains duplicate coordinates.")
    tile_key_set = set(tile_keys)
    allowed_logistics_tags = {
        "rail",
        "port",
        "coast",
        "coalStation",
        "telegraph",
        "expeditionaryDepot",
        "fieldWorks",
        "siegeDepot",
    }

    for tile in tiles:
        tile_key = f"{tile['q']},{tile['r']}"
        region_id = tile.get("regionId")
        if region_id not in region_id_set:
            errors.append(f"tile {tile_key} references unknown region {region_id}.")
        objective_id = tile.get("objectiveId")
        if objective_id is not None and objective_id not in objective_id_set:
            errors.append(f"tile {tile_key} references unknown objective {objective_id}.")
        controller = tile.get("controller")
        if controller not in factions:
            errors.append(f"tile {tile_key} has unknown controller {controller}.")
        supply_faction = tile.get("supplyFaction")
        if tile.get("isSupplySource") and supply_faction not in factions:
            errors.append(f"tile {tile_key} has unknown supplyFaction {supply_faction}.")
        unknown_logistics_tags = set(tile.get("logisticsTags", [])) - allowed_logistics_tags
        if unknown_logistics_tags:
            errors.append(f"tile {tile_key} has unknown logisticsTags: {sorted(unknown_logistics_tags)}")

    for key, region_id in regions.get("hexToRegion", {}).items():
        if key not in tile_key_set:
            errors.append(f"hexToRegion key {key} does not exist in scenario tiles.")
        if region_id not in region_id_set:
            errors.append(f"hexToRegion key {key} references unknown region {region_id}.")

    missing_hex_mappings = tile_key_set - set(regions.get("hexToRegion", {}).keys())
    if missing_hex_mappings:
        errors.append(f"hexToRegion is missing tile mappings: {sorted(missing_hex_mappings)}")

    for region in regions.get("regions", []):
        region_id = region["id"]
        owner = region.get("owner")
        controller = region.get("controller")
        if owner not in factions:
            errors.append(f"region {region_id} has unknown owner {owner}.")
        if controller not in factions:
            errors.append(f"region {region_id} has unknown controller {controller}.")

        display_hexes = {coord_key(hex_coord) for hex_coord in region.get("displayHexes", [])}
        missing_display_hexes = display_hexes - tile_key_set
        if missing_display_hexes:
            errors.append(f"region {region_id} displayHexes are not tiles: {sorted(missing_display_hexes)}")

        representative_key = coord_key(region["representativeHex"])
        if representative_key not in display_hexes:
            errors.append(f"region {region_id} representativeHex is outside displayHexes.")

        for neighbor_id in region.get("neighbors", []):
            neighbor = region_by_id.get(neighbor_id)
            if neighbor is None:
                errors.append(f"region {region_id} references unknown neighbor {neighbor_id}.")
            elif region_id not in neighbor.get("neighbors", []):
                errors.append(f"region {region_id} neighbor {neighbor_id} is not bidirectional.")

    for edge in regions.get("edges", []):
        from_id = edge["from"]
        to_id = edge["to"]
        from_region = region_by_id.get(from_id)
        to_region = region_by_id.get(to_id)
        if from_region is None or to_region is None:
            errors.append(f"edge {from_id}-{to_id} has an unknown endpoint.")
            continue
        if to_id not in from_region.get("neighbors", []):
            errors.append(f"edge {from_id}-{to_id} is not listed in from.neighbors.")
        if from_id not in to_region.get("neighbors", []):
            errors.append(f"edge {from_id}-{to_id} is not listed in to.neighbors.")

    template_ids = [template["id"] for template in templates.get("templates", [])]
    if len(template_ids) != len(set(template_ids)):
        errors.append("victorian_unit_templates contains duplicate ids.")
    template_id_set = set(template_ids)
    allowed_components = {
        "lineInfantry",
        "guardInfantry",
        "cavalry",
        "artillery",
        "engineers",
        "irregulars",
        "colonialInfantry",
        "supplyTrain",
    }
    for template in templates.get("templates", []):
        total_weight = sum(component["weight"] for component in template.get("components", []))
        if abs(total_weight - 1.0) > 0.0001:
            errors.append(f"template {template['id']} component weights sum to {total_weight}.")
        unknown_components = {
            component["type"]
            for component in template.get("components", [])
            if component["type"] not in allowed_components
        }
        if unknown_components:
            errors.append(f"template {template['id']} has unknown components: {sorted(unknown_components)}")

    unit_ids = [unit["id"] for unit in scenario.get("initialUnits", [])]
    if len(unit_ids) != len(set(unit_ids)):
        errors.append("scenario.initialUnits contains duplicate ids.")
    unit_id_set = set(unit_ids)
    unit_coord_keys = [coord_key(unit["coord"]) for unit in scenario.get("initialUnits", [])]
    if len(unit_coord_keys) != len(set(unit_coord_keys)):
        errors.append("scenario.initialUnits contains overlapping coordinates.")

    for unit in scenario.get("initialUnits", []):
        unit_id = unit["id"]
        if unit["faction"] not in factions:
            errors.append(f"unit {unit_id} has unknown faction {unit['faction']}.")
        if unit["templateId"] not in template_id_set:
            errors.append(f"unit {unit_id} references unknown template {unit['templateId']}.")
        unit_coord_key = coord_key(unit["coord"])
        if unit_coord_key not in tile_key_set:
            errors.append(f"unit {unit_id} is placed on missing tile {unit_coord_key}.")

    for condition in scenario.get("victoryConditions", []):
        objective_id = condition.get("objectiveId")
        if objective_id is not None and objective_id not in objective_id_set:
            errors.append(f"victory condition {condition['id']} references unknown objective {objective_id}.")
        for nested_objective_id in condition.get("objectiveIds") or []:
            if nested_objective_id not in objective_id_set:
                errors.append(
                    f"victory condition {condition['id']} references unknown objective {nested_objective_id}."
                )

    for supply_source in regions.get("supplySources", []):
        if supply_source.get("faction") not in factions:
            errors.append(f"supply source {supply_source['id']} has unknown faction {supply_source.get('faction')}.")
        if supply_source.get("regionId") not in region_id_set:
            errors.append(f"supply source {supply_source['id']} references unknown region.")

    persona_agents = personas.get("agents", [])
    persona_generals = personas.get("generals", [])
    for general in persona_generals:
        if general.get("faction") not in factions:
            errors.append(f"general {general['id']} has unknown faction {general.get('faction')}.")
    for agent in persona_agents:
        if agent.get("faction") not in factions:
            errors.append(f"agent {agent['id']} has unknown faction {agent.get('faction')}.")
        for division_id in agent.get("assignedDivisionIds", []):
            if division_id not in unit_id_set:
                errors.append(f"agent {agent['id']} references unknown division {division_id}.")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print(
        "Black Sea data ok: "
        f"{len(tiles)} tiles, "
        f"{len(region_ids)} regions, "
        f"{len(unit_ids)} units, "
        f"{len(persona_generals)} generals, "
        f"{len(persona_agents)} agents."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
