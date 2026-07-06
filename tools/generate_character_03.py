"""Generate the final modular low-poly DreamRunner character in Blender.

Paste this script into Blender's Scripting workspace and run it. It clears the
current Blender scene, creates the character procedurally, saves the authoring
file, and exports only the character hierarchy as a GLB.

The model is intentionally unrigged. Modular object origins are placed at the
anatomical attachment points used by DreamRunner's Godot procedural pivots.
"""

from __future__ import annotations

import math
import os
from pathlib import Path
from typing import Iterable, Sequence

import bmesh
import bpy
from mathutils import Matrix, Vector


BLEND_PATH = Path(r"D:\Projects\DreamRunner\assets\blender\dream_runner_character_03.blend")
GLB_PATH = Path(r"D:\Projects\DreamRunner\assets\models\characters\dream_runner_character_03.glb")
ROOT_NAME = "DreamRunnerCharacter03"
FRONT = Vector((0.0, -1.0, 0.0))

REQUIRED_OBJECT_NAMES = {
    "DR_Torso_Coat",
    "DR_Coat_Lower_Skirt",
    "DR_Coat_Back_Panel",
    "DR_Shoulder_Mantle",
    "DR_Waist_Belt",
    "DR_Chest_Signal",
    "DR_Hood_Head",
    "DR_Faceless_Mask",
    "DR_Neck",
    "DR_Hood_Cowl_Back",
    "DR_Left_Arm",
    "DR_Right_Arm",
    "DR_Left_Hand",
    "DR_Right_Hand",
    "DR_Left_Leg",
    "DR_Right_Leg",
    "DR_Left_Boot",
    "DR_Right_Boot",
    "DR_Left_Foot",
    "DR_Right_Foot",
    "DR_Scarf_Root",
    "DR_Hanging_Scarf",
    "DR_Scarf_Tail",
    "DR_Cloak_Left_Tail",
    "DR_Cloak_Right_Tail",
}


def clear_scene() -> None:
    """Remove every object and unused scene collection before generation."""
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for collection in list(bpy.data.collections):
        if collection.users == 0:
            bpy.data.collections.remove(collection)

    # Remove now-orphaned generated data so rerunning the script preserves the
    # exact required material and mesh names instead of creating .001 variants.
    for data_collection in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(data_collection):
            if datablock.users == 0:
                data_collection.remove(datablock)


def create_material(
    name: str,
    color: Sequence[float],
    *,
    roughness: float = 0.9,
    emission_color: Sequence[float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    """Create a simple Web-safe Principled material with optional emission."""
    material = bpy.data.materials.new(name=name)
    material.use_nodes = True
    material.diffuse_color = tuple(color)

    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError(f"Principled BSDF node missing for {name}")

    principled.inputs["Base Color"].default_value = tuple(color)
    principled.inputs["Roughness"].default_value = roughness
    if "Metallic" in principled.inputs:
        principled.inputs["Metallic"].default_value = 0.0

    if emission_color is not None and emission_strength > 0.0:
        emission_input = principled.inputs.get("Emission Color") or principled.inputs.get("Emission")
        strength_input = principled.inputs.get("Emission Strength")
        if emission_input is not None:
            emission_input.default_value = tuple(emission_color)
        if strength_input is not None:
            strength_input.default_value = emission_strength

    return material


def create_mesh_object(
    name: str,
    vertices: Sequence[Sequence[float] | Vector],
    faces: Sequence[Sequence[int]],
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Create a flat-shaded mesh object from explicit procedural geometry."""
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata([tuple(vertex) for vertex in vertices], [], faces)
    mesh.validate(verbose=False)
    mesh.update(calc_edges=True)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    for polygon in mesh.polygons:
        polygon.use_smooth = False
    mesh.materials.append(material)

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def set_object_origin_to_world(obj: bpy.types.Object, world_coordinate: Sequence[float]) -> None:
    """Move an object's origin without moving its visible world-space geometry."""
    world_origin = Vector(world_coordinate)
    local_origin = obj.matrix_world.inverted() @ world_origin
    if obj.type == "MESH":
        obj.data.transform(Matrix.Translation(-local_origin))
        obj.data.update()
    matrix = obj.matrix_world.copy()
    matrix.translation = world_origin
    obj.matrix_world = matrix


def parent_to_root_keep_transform(obj: bpy.types.Object, parent: bpy.types.Object) -> None:
    """Parent an object while preserving its authored world transform."""
    world_matrix = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world_matrix


def apply_transforms_safely(obj: bpy.types.Object) -> None:
    """Apply rotation/scale to a single object without disturbing selection."""
    previous_active = bpy.context.view_layer.objects.active
    previous_selection = list(bpy.context.selected_objects)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)
    for selected in previous_selection:
        if selected.name in bpy.context.view_layer.objects:
            selected.select_set(True)
    bpy.context.view_layer.objects.active = previous_active


def add_low_poly_bevel(obj: bpy.types.Object, width: float, segments: int = 1) -> None:
    """Add one restrained bevel pass to break box-like highlights and silhouettes."""
    if obj.type != "MESH" or width <= 0.0:
        return
    modifier = obj.modifiers.new(name="DR03_SilhouetteBevel", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(22.0)
    modifier.affect = "EDGES"

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    except RuntimeError as error:
        print(f"WARNING: bevel was skipped for {obj.name}: {error}")
        if modifier.name in obj.modifiers:
            obj.modifiers.remove(modifier)
    finally:
        obj.select_set(False)

    for polygon in obj.data.polygons:
        polygon.use_smooth = False


def create_tapered_prism(
    name: str,
    z_bottom: float,
    z_top: float,
    bottom_radius: Sequence[float],
    top_radius: Sequence[float],
    material: bpy.types.Material,
    *,
    center: Sequence[float] = (0.0, 0.0),
    bottom_offset: Sequence[float] = (0.0, 0.0),
    top_offset: Sequence[float] = (0.0, 0.0),
    segments: int = 8,
    origin: Sequence[float] | None = None,
    bevel: float = 0.008,
) -> bpy.types.Object:
    """Create an elliptical tapered prism with angular low-poly side planes."""
    cx, cy = center
    vertices: list[tuple[float, float, float]] = []
    angle_offset = math.pi / segments
    for ring_z, radius, offset in (
        (z_bottom, bottom_radius, bottom_offset),
        (z_top, top_radius, top_offset),
    ):
        for index in range(segments):
            angle = math.tau * index / segments + angle_offset
            vertices.append(
                (
                    cx + offset[0] + math.cos(angle) * radius[0],
                    cy + offset[1] + math.sin(angle) * radius[1],
                    ring_z,
                )
            )

    faces: list[tuple[int, ...]] = [tuple(reversed(range(segments)))]
    faces.append(tuple(range(segments, segments * 2)))
    for index in range(segments):
        next_index = (index + 1) % segments
        faces.append((index, next_index, segments + next_index, segments + index))

    obj = create_mesh_object(name, vertices, faces, material)
    set_object_origin_to_world(obj, origin or (cx, cy, z_bottom))
    add_low_poly_bevel(obj, bevel)
    return obj


def create_low_poly_cylinder(
    name: str,
    start: Sequence[float],
    end: Sequence[float],
    radius_start: float,
    radius_end: float,
    material: bpy.types.Material,
    *,
    segments: int = 8,
    origin: Sequence[float] | None = None,
    bevel: float = 0.006,
) -> bpy.types.Object:
    """Create a faceted cylinder between arbitrary world-space endpoints."""
    start_vector = Vector(start)
    end_vector = Vector(end)
    axis = end_vector - start_vector
    if axis.length < 1e-5:
        raise ValueError(f"Cylinder {name} has coincident endpoints")
    axis.normalize()
    reference = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.92 else Vector((1.0, 0.0, 0.0))
    ring_u = axis.cross(reference).normalized()
    ring_v = axis.cross(ring_u).normalized()

    vertices: list[Vector] = []
    for center, radius in ((start_vector, radius_start), (end_vector, radius_end)):
        for index in range(segments):
            angle = math.tau * index / segments
            vertices.append(center + ring_u * math.cos(angle) * radius + ring_v * math.sin(angle) * radius)

    faces: list[tuple[int, ...]] = [tuple(reversed(range(segments)))]
    faces.append(tuple(range(segments, segments * 2)))
    for index in range(segments):
        next_index = (index + 1) % segments
        faces.append((index, next_index, segments + next_index, segments + index))

    obj = create_mesh_object(name, vertices, faces, material)
    set_object_origin_to_world(obj, origin or start_vector)
    add_low_poly_bevel(obj, bevel)
    return obj


def create_angular_hood_mesh(
    name: str,
    material: bpy.types.Material,
    *,
    neck_origin: Sequence[float] = (0.0, 0.0, 1.47),
) -> bpy.types.Object:
    """Create a compact three-ring faceted hood with a forward brow silhouette."""
    ring_profiles = (
        ((0.0, 0.015, 1.46), (0.205, 0.155)),
        ((0.0, -0.005, 1.64), (0.198, 0.175)),
        ((0.0, 0.035, 1.775), (0.145, 0.13)),
    )
    segments = 8
    vertices: list[tuple[float, float, float]] = []
    for ring_index, (center, radius) in enumerate(ring_profiles):
        for index in range(segments):
            angle = math.tau * index / segments + math.pi / 8.0
            x = center[0] + math.cos(angle) * radius[0]
            y = center[1] + math.sin(angle) * radius[1]
            if ring_index == 1 and y < center[1]:
                y -= 0.025  # A restrained brow peak makes front/back unmistakable.
            vertices.append((x, y, center[2]))

    faces: list[tuple[int, ...]] = [tuple(reversed(range(segments)))]
    for ring_index in range(len(ring_profiles) - 1):
        first = ring_index * segments
        second = (ring_index + 1) * segments
        for index in range(segments):
            next_index = (index + 1) % segments
            faces.append((first + index, first + next_index, second + next_index, second + index))
    final_ring = (len(ring_profiles) - 1) * segments
    faces.append(tuple(range(final_ring, final_ring + segments)))

    obj = create_mesh_object(name, vertices, faces, material)
    set_object_origin_to_world(obj, neck_origin)
    add_low_poly_bevel(obj, 0.009)
    return obj


def create_trapezoid_cloak_panel(
    name: str,
    top_center: Sequence[float],
    bottom_center: Sequence[float],
    top_width: float,
    bottom_width: float,
    thickness: float,
    material: bpy.types.Material,
    *,
    origin: Sequence[float] | None = None,
    bevel: float = 0.005,
) -> bpy.types.Object:
    """Create a solid trapezoid panel for cloaks, coat edges, or scarf pieces."""
    top = Vector(top_center)
    bottom = Vector(bottom_center)
    down = (bottom - top).normalized()
    width_axis = Vector((1.0, 0.0, 0.0))
    normal = width_axis.cross(down)
    if normal.length < 1e-5:
        normal = Vector((0.0, 1.0, 0.0))
    normal.normalize()
    depth = normal * (thickness * 0.5)

    corners = (
        top - width_axis * (top_width * 0.5),
        top + width_axis * (top_width * 0.5),
        bottom + width_axis * (bottom_width * 0.5),
        bottom - width_axis * (bottom_width * 0.5),
    )
    vertices = [corner - depth for corner in corners] + [corner + depth for corner in corners]
    faces = (
        (0, 1, 2, 3),
        (7, 6, 5, 4),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (3, 7, 4, 0),
    )
    obj = create_mesh_object(name, vertices, faces, material)
    set_object_origin_to_world(obj, origin or top)
    add_low_poly_bevel(obj, bevel)
    return obj


def create_wedge_boot(
    name: str,
    x_center: float,
    z_bottom: float,
    z_top_back: float,
    z_top_front: float,
    back_y: float,
    front_y: float,
    heel_width: float,
    toe_width: float,
    material: bpy.types.Material,
    *,
    origin: Sequence[float],
    bevel: float = 0.008,
) -> bpy.types.Object:
    """Create a broad, tapered forward wedge that reads as a heavy runner boot."""
    vertices = (
        (x_center - heel_width, back_y, z_bottom),
        (x_center + heel_width, back_y, z_bottom),
        (x_center + toe_width, front_y, z_bottom),
        (x_center - toe_width, front_y, z_bottom),
        (x_center - heel_width * 0.92, back_y, z_top_back),
        (x_center + heel_width * 0.92, back_y, z_top_back),
        (x_center + toe_width * 0.82, front_y, z_top_front),
        (x_center - toe_width * 0.82, front_y, z_top_front),
    )
    faces = (
        (3, 2, 1, 0),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    )
    obj = create_mesh_object(name, vertices, faces, material)
    set_object_origin_to_world(obj, origin)
    add_low_poly_bevel(obj, bevel)
    return obj


def create_character_materials() -> dict[str, bpy.types.Material]:
    return {
        "coat": create_material("MAT_DR03_Coat_Dark_Olive", (0.09, 0.125, 0.095, 1.0)),
        "edge": create_material("MAT_DR03_Coat_Dust_Edge", (0.20, 0.21, 0.145, 1.0)),
        "pants": create_material("MAT_DR03_Pants_Charcoal", (0.055, 0.065, 0.055, 1.0)),
        "boots": create_material("MAT_DR03_Boots_Heavy_Dark", (0.035, 0.030, 0.025, 1.0)),
        "leather": create_material("MAT_DR03_Leather_Brown", (0.13, 0.075, 0.040, 1.0)),
        "hood": create_material("MAT_DR03_Hood_Deep", (0.045, 0.065, 0.055, 1.0)),
        "mask": create_material("MAT_DR03_Faceless_Mask", (0.52, 0.52, 0.46, 1.0), roughness=0.78),
        "scarf": create_material("MAT_DR03_Scarf_Rust", (0.30, 0.12, 0.065, 1.0)),
        "signal": create_material(
            "MAT_DR03_Chest_Signal_Emissive",
            (0.12, 0.30, 0.27, 1.0),
            roughness=0.48,
            emission_color=(0.38, 0.95, 0.85, 1.0),
            emission_strength=2.2,
        ),
    }


def build_character(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    """Build and parent the complete modular character hierarchy."""
    objects: dict[str, bpy.types.Object] = {}

    def register(obj: bpy.types.Object, parent: bpy.types.Object = root) -> bpy.types.Object:
        parent_to_root_keep_transform(obj, parent)
        objects[obj.name] = obj
        return obj

    torso = register(create_tapered_prism(
        "DR_Torso_Coat", 0.96, 1.46, (0.19, 0.13), (0.315, 0.175), materials["coat"],
        bottom_offset=(0.0, 0.005), top_offset=(0.012, 0.0), origin=(0.0, 0.0, 0.98), bevel=0.012,
    ))
    register(create_tapered_prism(
        "DR_Coat_Lower_Skirt", 0.68, 1.04, (0.29, 0.17), (0.19, 0.135), materials["coat"],
        bottom_offset=(0.015, 0.025), origin=(0.0, 0.0, 1.0), bevel=0.01,
    ), torso)
    register(create_tapered_prism(
        "DR_Shoulder_Mantle", 1.32, 1.49, (0.325, 0.185), (0.285, 0.17), materials["edge"],
        center=(0.01, 0.015), origin=(0.0, 0.0, 1.38), bevel=0.01,
    ), torso)
    register(create_tapered_prism(
        "DR_Waist_Belt", 0.965, 1.015, (0.21, 0.145), (0.21, 0.145),
        materials["leather"], origin=(0.0, 0.0, 0.99), segments=8, bevel=0.004,
    ), torso)
    register(create_trapezoid_cloak_panel(
        "DR_Coat_Back_Panel", (0.0, 0.145, 1.38), (0.025, 0.245, 0.69), 0.48, 0.57, 0.035,
        materials["coat"], origin=(0.0, 0.145, 1.38), bevel=0.007,
    ), torso)
    register(create_trapezoid_cloak_panel(
        "DR_Coat_Edge_Left", (-0.14, -0.14, 1.02), (-0.19, -0.15, 0.68), 0.07, 0.10, 0.018,
        materials["edge"], origin=(-0.14, -0.14, 1.02), bevel=0.003,
    ), torso)
    register(create_trapezoid_cloak_panel(
        "DR_Coat_Edge_Right", (0.14, -0.14, 1.02), (0.205, -0.14, 0.72), 0.065, 0.085, 0.018,
        materials["edge"], origin=(0.14, -0.14, 1.02), bevel=0.003,
    ), torso)

    neck = register(create_low_poly_cylinder(
        "DR_Neck", (0.0, 0.01, 1.42), (0.0, 0.01, 1.53), 0.09, 0.082,
        materials["hood"], segments=8, origin=(0.0, 0.0, 1.47), bevel=0.004,
    ), torso)
    hood = register(create_angular_hood_mesh("DR_Hood_Head", materials["hood"]), root)
    register(create_trapezoid_cloak_panel(
        "DR_Faceless_Mask", (0.0, -0.18, 1.70), (0.0, -0.205, 1.52), 0.18, 0.135, 0.018,
        materials["mask"], origin=(0.0, 0.0, 1.47), bevel=0.004,
    ), hood)
    register(create_trapezoid_cloak_panel(
        "DR_Hood_Cowl_Back", (0.0, 0.12, 1.58), (0.0, 0.18, 1.36), 0.28, 0.38, 0.035,
        materials["hood"], origin=(0.0, 0.08, 1.47), bevel=0.006,
    ), hood)

    signal = register(create_low_poly_cylinder(
        "DR_Chest_Signal", (0.0, -0.165, 1.285), (0.0, -0.225, 1.285), 0.041, 0.035,
        materials["signal"], segments=8, origin=(0.0, -0.16, 1.285), bevel=0.003,
    ), torso)
    signal["dreamrunner_accent"] = True
    neck["procedural_attachment"] = "neck"

    shoulder_left = (-0.305, 0.005, 1.40)
    shoulder_right = (0.325, 0.0, 1.405)
    left_arm = register(create_low_poly_cylinder(
        "DR_Left_Arm", shoulder_left, (-0.30, -0.005, 0.91), 0.078, 0.058,
        materials["coat"], segments=6, origin=shoulder_left, bevel=0.007,
    ))
    right_arm = register(create_low_poly_cylinder(
        "DR_Right_Arm", shoulder_right, (0.34, 0.0, 0.92), 0.082, 0.06,
        materials["coat"], segments=6, origin=shoulder_right, bevel=0.007,
    ))
    register(create_tapered_prism(
        "DR_Left_Hand", 0.81, 0.94, (0.055, 0.045), (0.062, 0.052), materials["leather"],
        center=(-0.30, -0.02), origin=(-0.30, 0.0, 0.91), segments=6, bevel=0.005,
    ), left_arm)
    register(create_tapered_prism(
        "DR_Right_Hand", 0.82, 0.95, (0.058, 0.047), (0.064, 0.053), materials["leather"],
        center=(0.34, -0.015), origin=(0.34, 0.0, 0.92), segments=6, bevel=0.005,
    ), right_arm)
    register(create_tapered_prism(
        "DR_Right_Shoulder_Guard", 1.31, 1.48, (0.11, 0.12), (0.13, 0.13), materials["edge"],
        center=(0.30, 0.005), top_offset=(0.02, 0.0), origin=shoulder_right, segments=6, bevel=0.008,
    ), right_arm)

    hip_left = (-0.125, 0.0, 0.92)
    hip_right = (0.13, 0.0, 0.92)
    left_leg = register(create_low_poly_cylinder(
        "DR_Left_Leg", hip_left, (-0.135, 0.01, 0.42), 0.095, 0.078,
        materials["pants"], segments=6, origin=hip_left, bevel=0.006,
    ))
    right_leg = register(create_low_poly_cylinder(
        "DR_Right_Leg", hip_right, (0.14, 0.005, 0.42), 0.098, 0.08,
        materials["pants"], segments=6, origin=hip_right, bevel=0.006,
    ))
    left_boot = register(create_tapered_prism(
        "DR_Left_Boot", 0.12, 0.50, (0.115, 0.105), (0.09, 0.085), materials["boots"],
        center=(-0.135, -0.005), origin=(-0.135, 0.0, 0.42), segments=6, bevel=0.009,
    ), left_leg)
    right_boot = register(create_tapered_prism(
        "DR_Right_Boot", 0.12, 0.50, (0.118, 0.108), (0.092, 0.087), materials["boots"],
        center=(0.14, 0.0), origin=(0.14, 0.0, 0.42), segments=6, bevel=0.009,
    ), right_leg)
    left_foot = register(create_wedge_boot(
        "DR_Left_Foot", -0.135, 0.035, 0.19, 0.145, 0.105, -0.30, 0.105, 0.145,
        materials["boots"], origin=(-0.135, 0.0, 0.14), bevel=0.009,
    ), left_leg)
    right_foot = register(create_wedge_boot(
        "DR_Right_Foot", 0.14, 0.035, 0.195, 0.15, 0.11, -0.31, 0.108, 0.15,
        materials["boots"], origin=(0.14, 0.0, 0.14), bevel=0.009,
    ), right_leg)
    register(create_wedge_boot(
        "DR_Boot_Sole_Left", -0.135, 0.0, 0.055, 0.045, 0.115, -0.315, 0.112, 0.153,
        materials["leather"], origin=(-0.135, 0.0, 0.04), bevel=0.003,
    ), left_foot)
    register(create_wedge_boot(
        "DR_Boot_Sole_Right", 0.14, 0.0, 0.058, 0.048, 0.12, -0.325, 0.115, 0.158,
        materials["leather"], origin=(0.14, 0.0, 0.04), bevel=0.003,
    ), right_foot)

    register(create_trapezoid_cloak_panel(
        "DR_Left_Knee_Pad", (-0.135, -0.085, 0.59), (-0.135, -0.105, 0.44), 0.135, 0.11, 0.025,
        materials["leather"], origin=(-0.135, 0.0, 0.55), bevel=0.004,
    ), left_leg)
    register(create_trapezoid_cloak_panel(
        "DR_Right_Knee_Pad", (0.14, -0.088, 0.58), (0.14, -0.108, 0.45), 0.12, 0.105, 0.025,
        materials["edge"], origin=(0.14, 0.0, 0.55), bevel=0.004,
    ), right_leg)

    scarf_root = register(create_tapered_prism(
        "DR_Scarf_Root", 1.425, 1.525, (0.145, 0.125), (0.125, 0.115), materials["scarf"],
        center=(-0.025, -0.005), origin=(-0.06, 0.0, 1.48), segments=8, bevel=0.006,
    ))
    register(create_trapezoid_cloak_panel(
        "DR_Hanging_Scarf", (-0.09, -0.165, 1.47), (-0.13, -0.19, 1.09), 0.115, 0.095, 0.022,
        materials["scarf"], origin=(-0.09, -0.13, 1.47), bevel=0.004,
    ), scarf_root)
    register(create_trapezoid_cloak_panel(
        "DR_Scarf_Tail", (-0.055, 0.11, 1.49), (-0.245, 0.43, 1.08), 0.12, 0.075, 0.025,
        materials["scarf"], origin=(-0.055, 0.11, 1.49), bevel=0.004,
    ), scarf_root)

    register(create_trapezoid_cloak_panel(
        "DR_Cloak_Left_Tail", (-0.14, 0.14, 1.23), (-0.20, 0.29, 0.54), 0.25, 0.28, 0.03,
        materials["coat"], origin=(-0.14, 0.14, 1.23), bevel=0.006,
    ), torso)
    register(create_trapezoid_cloak_panel(
        "DR_Cloak_Right_Tail", (0.14, 0.14, 1.23), (0.23, 0.25, 0.62), 0.24, 0.255, 0.03,
        materials["coat"], origin=(0.14, 0.14, 1.23), bevel=0.006,
    ), torso)

    register(create_tapered_prism(
        "DR_Hip_Gear_Left", 0.76, 1.01, (0.075, 0.055), (0.065, 0.05), materials["leather"],
        center=(-0.255, 0.015), bottom_offset=(-0.015, 0.015), origin=(-0.23, 0.0, 0.96),
        segments=6, bevel=0.006,
    ), torso)
    register(create_tapered_prism(
        "DR_Back_Pack_Shadow", 1.04, 1.37, (0.17, 0.075), (0.145, 0.065), materials["hood"],
        center=(0.0, 0.19), top_offset=(0.0, -0.01), origin=(0.0, 0.14, 1.33),
        segments=8, bevel=0.01,
    ), torso)

    for obj in objects.values():
        apply_transforms_safely(obj)
        obj["dreamrunner_module"] = True
    return list(objects.values())


def create_preview_setup() -> None:
    """Create unexported camera/light helpers for inspecting the saved blend."""
    camera_data = bpy.data.cameras.new("PREVIEW_DR03_CameraData")
    camera = bpy.data.objects.new("PREVIEW_DR03_Camera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = (3.0, -5.8, 2.25)
    camera.data.lens = 58.0
    point_camera_at(camera, Vector((0.0, 0.0, 0.92)))
    bpy.context.scene.camera = camera

    key_data = bpy.data.lights.new("PREVIEW_DR03_KeyData", type="AREA")
    key_data.energy = 700.0
    key_data.shape = "DISK"
    key_data.size = 4.0
    key = bpy.data.objects.new("PREVIEW_DR03_Key", key_data)
    bpy.context.scene.collection.objects.link(key)
    key.location = (-3.5, -4.0, 5.0)
    point_camera_at(key, Vector((0.0, 0.0, 1.0)))

    fill_data = bpy.data.lights.new("PREVIEW_DR03_FillData", type="AREA")
    fill_data.energy = 280.0
    fill_data.color = (0.48, 0.63, 0.72)
    fill_data.size = 3.0
    fill = bpy.data.objects.new("PREVIEW_DR03_Fill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = (3.0, 1.8, 3.0)
    point_camera_at(fill, Vector((0.0, 0.0, 1.0)))

    world = bpy.context.scene.world or bpy.data.worlds.new("DR03_PreviewWorld")
    bpy.context.scene.world = world
    world.color = (0.025, 0.03, 0.025)


def point_camera_at(obj: bpy.types.Object, target: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def get_export_objects(root: bpy.types.Object) -> list[bpy.types.Object]:
    return [root] + sorted(
        (obj for obj in bpy.data.objects if obj.name.startswith("DR_")),
        key=lambda obj: obj.name,
    )


def select_only_export_objects(root: bpy.types.Object) -> list[bpy.types.Object]:
    bpy.ops.object.select_all(action="DESELECT")
    export_objects = get_export_objects(root)
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    return export_objects


def count_triangles(objects: Iterable[bpy.types.Object]) -> int:
    """Count evaluated triangles for selected mesh objects."""
    triangle_count = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangle_count += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return triangle_count


def character_bottom_z(objects: Iterable[bpy.types.Object]) -> float:
    minimum_z = math.inf
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            minimum_z = min(minimum_z, (obj.matrix_world @ Vector(corner)).z)
    return minimum_z


def validate_character(root: bpy.types.Object, export_objects: list[bpy.types.Object]) -> tuple[int, float]:
    """Print validation warnings without silently exporting malformed content."""
    object_names = {obj.name for obj in bpy.data.objects}
    missing = sorted(REQUIRED_OBJECT_NAMES - object_names)
    if missing:
        print(f"WARNING: missing required objects: {', '.join(missing)}")
    else:
        print("[OK] All required DR03 objects exist.")

    selected = list(bpy.context.selected_objects)
    invalid_selected = [
        obj.name for obj in selected
        if obj.name != ROOT_NAME and not obj.name.startswith("DR_")
    ]
    if invalid_selected:
        print(f"WARNING: non-character objects selected for export: {invalid_selected}")
    elif {obj.name for obj in selected} != {obj.name for obj in export_objects}:
        print("WARNING: export selection does not exactly match the character object set.")
    else:
        print("[OK] Export selection contains only DreamRunnerCharacter03 and DR_ objects.")

    unparented = [
        obj.name for obj in export_objects
        if obj is not root and root not in obj.parent_recursive
    ]
    if unparented:
        print(f"WARNING: character objects outside the root hierarchy: {unparented}")

    triangles = count_triangles(export_objects)
    if triangles > 7000:
        print(f"WARNING: triangle budget exceeded: {triangles} > 7000")
    elif triangles < 2000:
        print(f"WARNING: triangle count is below the 2,000 target: {triangles}")
    else:
        print(f"[OK] Triangle target met: {triangles}")

    bottom_z = character_bottom_z(export_objects)
    if not math.isfinite(bottom_z) or abs(bottom_z) > 0.015:
        print(f"WARNING: character bottom is not near Z=0: {bottom_z:.5f}")
    else:
        print(f"[OK] Character is grounded at Z={bottom_z:.5f}")

    return triangles, bottom_z


def save_and_export(root: bpy.types.Object) -> None:
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)

    export_objects = select_only_export_objects(root)
    triangles, bottom_z = validate_character(root, export_objects)

    bpy.ops.wm.save_as_mainfile(filepath=os.fspath(BLEND_PATH))
    # Saving preserves selection, but select again so export remains explicit if
    # Blender changes active-object state during save handlers.
    export_objects = select_only_export_objects(root)
    bpy.ops.export_scene.gltf(
        filepath=os.fspath(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_skins=False,
        export_morph=False,
        export_texcoords=False,
        export_tangents=False,
    )

    print("=" * 68)
    print("DreamRunner Character 03 generation complete")
    print(f"Final export object count: {len(export_objects)}")
    print(f"Final triangle count: {triangles}")
    print(f"Character bottom Z: {bottom_z:.5f}")
    print(f"Saved path: {BLEND_PATH}")
    print(f"Exported path: {GLB_PATH}")
    print("=" * 68)


def main() -> None:
    clear_scene()
    materials = create_character_materials()

    root = bpy.data.objects.new(ROOT_NAME, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.25
    root["dreamrunner_character_version"] = 3
    root["front_direction"] = "-Y"
    bpy.context.scene.collection.objects.link(root)

    build_character(root, materials)
    create_preview_setup()
    save_and_export(root)


if __name__ == "__main__":
    main()
