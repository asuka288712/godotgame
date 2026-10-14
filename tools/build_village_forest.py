"""Extract Image 2 sheets and build editable village vegetation nodes.
Run with the bundled Python (Pillow). Source prompts remain in output/imagegen/village_forest.
"""
from pathlib import Path
import math
import random
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/generated/village_forest'
SOURCE = ROOT / 'output/imagegen/village_forest'
TREE_NAMES = ['camphor', 'pine', 'sapling', 'old_tree']
PROP_NAMES = ['grass', 'fern', 'bush', 'wildflowers', 'reeds', 'moss_stones']
TRAIL = [(12, 0), (12, 6), (16, 10), (20, 12), (22, 17), (24, 23), (25, 27)]


def extract(sheet, columns, rows, names):
    image = Image.open(SOURCE / sheet).convert('RGBA')
    for index, name in enumerate(names):
        col, row = index % columns, index // columns
        cell = image.crop((round(col * image.width / columns), round(row * image.height / rows),
                           round((col + 1) * image.width / columns), round((row + 1) * image.height / rows)))
        pixels = []
        for red, green, blue, alpha in cell.getdata():
            # Remove the solid chroma background, including antialiased edge spill.
            spill = min(red, blue) - green
            if spill > 65:
                alpha = round(alpha * max(0, min(1, (130 - spill) / 65)))
                if alpha:
                    red, blue = min(red, green + 35), min(blue, green + 35)
            if alpha < 12:
                alpha = 0
            pixels.append((red, green, blue, alpha))
        cell.putdata(pixels)
        bounds = cell.getchannel('A').getbbox()
        if not bounds:
            raise ValueError('Empty generated prop: ' + name)
        cell = cell.crop(bounds)
        padded = Image.new('RGBA', (cell.width + 8, cell.height + 8))
        padded.paste(cell, (4, 4))
        padded.save(OUT / (name + '.png'))


def trail_distance(x, z):
    nearest = float('inf')
    for (ax, az), (bx, bz) in zip(TRAIL, TRAIL[1:]):
        dx, dz = bx - ax, bz - az
        t = max(0, min(1, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        nearest = min(nearest, math.hypot(x - ax - t * dx, z - az - t * dz))
    return nearest


def build():
    rng = random.Random(1010)
    ext = [f'[ext_resource type="Texture2D" path="res://assets/generated/village_forest/{n}.png" id="{n}"]' for n in TREE_NAMES + PROP_NAMES]
    ext += ['[ext_resource type="Script" path="res://scripts/village_vegetation.gd" id="fade"]',
            '[ext_resource type="FontFile" path="res://assets/fonts/font.ttf" id="font"]',
            '[ext_resource type="Texture2D" path="res://assets/generated/terrain/village_gravel_path_tile.png" id="trail_texture"]']
    resources = ['[sub_resource type="CylinderShape3D" id="trunk"]\nradius = 0.32\nheight = 2.0',
                 '[sub_resource type="StandardMaterial3D" id="soil"]\nalbedo_color = Color(0.7, 0.62, 0.46, 1)\nalbedo_texture = ExtResource("trail_texture")\nuv1_triplanar = true\nuv1_world_triplanar = true\nuv1_scale = Vector3(0.4, 0.4, 0.4)\nroughness = 1.0',
                 '[sub_resource type="CylinderMesh" id="trail_cap"]\ntop_radius = 1.48\nbottom_radius = 1.48\nheight = 0.016\nradial_segments = 16\nmaterial = SubResource("soil")']
    nodes = ['[node name="VillageVegetation" type="Node3D"]\nscript = ExtResource("fade")',
             '[node name="Forest" type="Node3D" parent="."]',
             '[node name="Trail" type="Node3D" parent="Forest"]',
             '[node name="Trees" type="Node3D" parent="Forest"]',
             '[node name="GroundPlants" type="Node3D" parent="."]']
    for i, ((ax, az), (bx, bz)) in enumerate(zip(TRAIL, TRAIL[1:])):
        length = math.hypot(bx - ax, bz - az)
        resources.append(f'[sub_resource type="PlaneMesh" id="trail_{i}"]\nsize = Vector2(2.95, {length:.4f})\nmaterial = SubResource("soil")')
        nodes.append(f'[node name="Path{i:02}" type="MeshInstance3D" parent="Forest/Trail"]\nposition = Vector3({(ax+bx)/2}, 0.047, {(az+bz)/2})\nrotation = Vector3(0, {math.atan2(bx-ax,bz-az):.5f}, 0)\nmesh = SubResource("trail_{i}")\ncast_shadow = 0')
    for i, (x, z) in enumerate(TRAIL):
        nodes.append(f'[node name="Bend{i:02}" type="MeshInstance3D" parent="Forest/Trail"]\nposition = Vector3({x}, 0.047, {z})\nmesh = SubResource("trail_cap")\ncast_shadow = 0')
    tree_count = 0
    for x0 in range(9, 30, 3):
        for z0 in range(6, 30, 3):
            x, z = x0 + rng.uniform(-.6, .6), z0 + rng.uniform(-.6, .6)
            if trail_distance(x, z) < 2.75 or (x < 11 and z < 9):
                continue
            name = rng.choices(TREE_NAMES, [5, 3, 2, 2])[0]
            height = rng.uniform(4.4, 6.2) if name != 'sapling' else rng.uniform(3.5, 4.5)
            texture = Image.open(OUT / (name + '.png'))
            pixel = height / texture.height
            tree_count += 1
            path = f'Forest/Trees/Tree{tree_count:02}'
            nodes.append(f'[node name="Tree{tree_count:02}" type="StaticBody3D" parent="Forest/Trees"]\nposition = Vector3({x:.3f}, 0.02, {z:.3f})')
            nodes.append(f'[node name="TrunkCollision" type="CollisionShape3D" parent="{path}"]\nposition = Vector3(0, 1.0, 0)\nshape = SubResource("trunk")')
            nodes.append(f'[node name="Canopy" type="Sprite3D" parent="{path}" groups=["village_canopies"]]\nposition = Vector3(0, {height/2:.4f}, 0)\ntexture = ExtResource("{name}")\npixel_size = {pixel:.7f}\nbillboard = 2\nshaded = true\ntexture_filter = 0\nalpha_cut = 0\nno_depth_test = false\ncast_shadow = 0\nflip_h = {str(rng.random()<.5).lower()}')
    props = []
    # Sparse meadow decoration away from buildings, doors and the village crossroads.
    for _ in range(155):
        x, z = rng.uniform(-28, 28), rng.uniform(-27, 28)
        if abs(x) < 2.6 or abs(z) < 2.8 or (x < 5 and z < -2) or (x > 7 and z > 4):
            continue
        if any(math.hypot(x-px,z-pz) < 1.2 for px,pz,_ in props):
            continue
        props.append((x, z, rng.choice(PROP_NAMES)))
    for _ in range(185):
        x, z = rng.uniform(8, 29), rng.uniform(4, 29)
        if trail_distance(x,z) < 1.85:
            continue
        props.append((x, z, rng.choices(PROP_NAMES,[5,5,3,1,1,3])[0]))
    for i, (x, z, name) in enumerate(props):
        height = rng.uniform(.28,.65) if name in ['grass','wildflowers','moss_stones'] else rng.uniform(.5,.95)
        texture = Image.open(OUT / (name+'.png'))
        pixel = height / texture.height
        nodes.append(f'[node name="{name.title().replace("_", "")}{i:03}" type="Sprite3D" parent="GroundPlants"]\nposition = Vector3({x:.3f}, {height/2+.025:.4f}, {z:.3f})\ntexture = ExtResource("{name}")\npixel_size = {pixel:.7f}\nbillboard = 2\nshaded = true\ntexture_filter = 0\nalpha_cut = 1\nalpha_scissor_threshold = 0.35\ncast_shadow = 0\nflip_h = {str(rng.random()<.5).lower()}')
    nodes.append('[node name="ForestSign" type="Label3D" parent="Forest"]\nposition = Vector3(10.5, 1.7, 4)\ntext = "林间小路 · 十里坡"\nfont = ExtResource("font")\nfont_size = 28\npixel_size = 0.012\nbillboard = 1\noutline_size = 6')
    (ROOT / 'scenes/village_vegetation.tscn').write_text('[gd_scene format=3]\n\n' + '\n\n'.join(ext + resources + nodes) + '\n')
    print(f'Built {tree_count} solid trees, {len(props)} ground props, {len(TRAIL)-1} trail segments.')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    extract('forest_trees_sheet.png', 2, 2, TREE_NAMES)
    extract('ground_props_sheet.png', 3, 2, PROP_NAMES)
    build()
