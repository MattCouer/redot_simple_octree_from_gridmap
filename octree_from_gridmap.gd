@tool
class_name octree_from_gridmap
extends Node


class octree_part:
	extends RefCounted
	var children : Array[octree_part];
	var octant_lower_bound : Vector3;
	var octant_upper_bound : Vector3;
	
	func _init(_lower_bound : Vector3, _upper_bound : Vector3):
		octant_lower_bound = _lower_bound;
		octant_upper_bound = _upper_bound;

class octree:
	extends RefCounted
	var root : octree_part;
	
	func _init(_root : octree_part):
		root = _root;

## Mesh local to gridmap
var display_octree : bool;
var grid_map : GridMap;
## An octant is allowed grid_item_density or less before it divides
var grid_item_density : int = 1;
var custom_unit_octant : bool;
## Is custom_lower(upper)_bound relative to grid minimum(maximum) Property unused unless custom_unit_octant is true
var relative_to_grid : bool;
## Property unused unless custom_unit_octant is true
var custom_lower_bound : Vector3;
## Property unused unless custom_unit_octant is true
var custom_upper_bound : Vector3;

var raster : octree;
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if(not (Engine.is_editor_hint())):
		if (grid_map == null):
			printerr("Grid map property is null.");
			return;
		
		if (grid_map.get_used_cells().size() == 0):
			printerr("Grid map " + grid_map.name + " has no cell items to make a octree. Aborting construction...")
			return;
		if(custom_unit_octant):
			if(custom_lower_bound == custom_upper_bound):
				printerr("custom_lower_bound == custom_upper_bound expect undefined behaviour");
			if(custom_lower_bound.x > custom_upper_bound.x):
				printerr("custom_lower_bound.x > custom_upper_bound.x expect undefined behaviour");
			if(custom_lower_bound.y > custom_upper_bound.y):
				printerr("custom_lower_bound.y > custom_upper_bound.y expect undefined behaviour");
			if(custom_lower_bound.z > custom_upper_bound.z):
				printerr("custom_lower_bound.z > custom_upper_bound.z expect undefined behaviour");
				
		gen_octree_from_gridmap();
		
		if (display_octree):
			
			var mi : MeshInstance3D = MeshInstance3D.new();
			var am : ArrayMesh = ArrayMesh.new();
			
			var arrays : Array;
			arrays.resize(Mesh.ARRAY_MAX);
			var vertices : PackedVector3Array;
			var indices : PackedInt32Array;
			
			gen_arrays_for_octree(raster.root, vertices, indices);
			arrays[Mesh.ARRAY_VERTEX] = vertices;
			arrays[Mesh.ARRAY_INDEX] = indices;
			
			am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays);
			
			
			
			var mat : StandardMaterial3D = StandardMaterial3D.new();
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;
			mat.albedo_color = Color.AQUA;
			
			am.surface_set_material(0, mat);
			
			mi.mesh = am;
			
			var add_mi : Callable = func() -> void: \
				grid_map.add_child(mi); \
				mi.global_position = Vector3.ZERO;
			
			add_mi.call_deferred();
		

func gen_octree_from_gridmap() -> void:
	var min_cell_idx : Vector3i;
	#Calculate min bound
	for dim in 3:
		for cell_idx : int in grid_map.get_used_cells().size():
			if(cell_idx == 0):
				min_cell_idx[dim] = cell_idx;
				continue;
			if(grid_map.get_used_cells()[cell_idx][dim] < grid_map.get_used_cells()[min_cell_idx[dim]][dim]):
				min_cell_idx[dim] = cell_idx;
	var min_x_cell_position : int = grid_map.get_used_cells()[min_cell_idx[0]][0];
	var min_y_cell_position : int = grid_map.get_used_cells()[min_cell_idx[1]][1];
	var min_z_cell_position : int = grid_map.get_used_cells()[min_cell_idx[2]][2];
	#Calculate max bound
	var max_cell_idx : Vector3i;
	for dim in 3:
		for cell_idx : int in grid_map.get_used_cells().size():
			if(cell_idx == 0):
				max_cell_idx[dim] = cell_idx;
				continue;
			if(grid_map.get_used_cells()[cell_idx][dim] > grid_map.get_used_cells()[max_cell_idx[dim]][dim]):
				max_cell_idx[dim] = cell_idx;
	var max_x_cell_position : int = grid_map.get_used_cells()[max_cell_idx[0]][0];
	var max_y_cell_position : int = grid_map.get_used_cells()[max_cell_idx[1]][1];
	var max_z_cell_position : int = grid_map.get_used_cells()[max_cell_idx[2]][2];
	#Actualize positions
	min_x_cell_position *= grid_map.cell_size.x;
	min_y_cell_position *= grid_map.cell_size.y;
	min_z_cell_position *= grid_map.cell_size.z;
	min_x_cell_position += (grid_map.cell_size.x/2) * int(grid_map.cell_center_x);
	min_y_cell_position += (grid_map.cell_size.y/2) * int(grid_map.cell_center_y);
	min_z_cell_position += (grid_map.cell_size.z/2) * int(grid_map.cell_center_z);
	max_x_cell_position *= grid_map.cell_size.x;
	max_y_cell_position *= grid_map.cell_size.y;
	max_z_cell_position *= grid_map.cell_size.z;
	max_x_cell_position += (grid_map.cell_size.x/2) * int(grid_map.cell_center_x);
	max_y_cell_position += (grid_map.cell_size.y/2) * int(grid_map.cell_center_y);
	max_z_cell_position += (grid_map.cell_size.z/2) * int(grid_map.cell_center_z);
	
	var min_dim : Vector3 = Vector3(min_x_cell_position, min_y_cell_position, min_z_cell_position);
	var max_dim : Vector3 = Vector3(max_x_cell_position, max_y_cell_position, max_z_cell_position);
	
	if(custom_unit_octant):
		if(relative_to_grid):
			raster = octree.new(octree_part.new(min_dim + custom_lower_bound, max_dim + custom_upper_bound));
		else:
			raster = octree.new(octree_part.new(custom_lower_bound, custom_upper_bound));
	else:
		raster = octree.new(octree_part.new(min_dim, max_dim));
		
		
	divide_gridmap_octree_part(raster.root);

func divide_gridmap_octree_part(part : octree_part) -> void:
	var num_of_cells_in_octree_part : int = 0;
	for cell : Vector3i in grid_map.get_used_cells():
		#Actualize positions
		var test : Vector3i = cell;
		test.x *= grid_map.cell_size.x;
		test.y *= grid_map.cell_size.y;
		test.z *= grid_map.cell_size.z;
		test.x += (grid_map.cell_size.x/2) * int(grid_map.cell_center_x);
		test.y += (grid_map.cell_size.y/2) * int(grid_map.cell_center_y);
		test.z += (grid_map.cell_size.z/2) * int(grid_map.cell_center_z);
		if(((test.x >= part.octant_lower_bound.x) and (test.y >= part.octant_lower_bound.y) and (test.z >= part.octant_lower_bound.z)) \
			and ((test.x <= part.octant_upper_bound.x) and (test.y <= part.octant_upper_bound.y) and (test.z <= part.octant_upper_bound.z))):
			num_of_cells_in_octree_part += 1;
	
	if(num_of_cells_in_octree_part > grid_item_density):
		var center : Vector3 = (part.octant_lower_bound + part.octant_upper_bound)/2;
		#Z Pattern
		part.children.push_back(octree_part.new(part.octant_lower_bound, center));
		part.children.push_back(octree_part.new(\
			Vector3(part.octant_lower_bound.x, part.octant_lower_bound.y, center.z) \
				, Vector3(center.x, center.y, part.octant_upper_bound.z)));
		part.children.push_back(octree_part.new(\
			Vector3(center.x, part.octant_lower_bound.y, part.octant_lower_bound.z) \
				, Vector3(part.octant_upper_bound.x, center.y, center.z)));
		part.children.push_back(octree_part.new(\
			Vector3(center.x, part.octant_lower_bound.y, center.z) \
				, Vector3(part.octant_upper_bound.x, center.y, part.octant_upper_bound.z)));
		part.children.push_back(octree_part.new(\
			Vector3(part.octant_lower_bound.x, center.y, part.octant_lower_bound.z) \
				, Vector3(center.x, part.octant_upper_bound.y, center.z)));
		part.children.push_back(octree_part.new(\
			Vector3(part.octant_lower_bound.x, center.y, center.z) \
				, Vector3(center.x, part.octant_upper_bound.y, part.octant_upper_bound.z)));
		part.children.push_back(octree_part.new(\
			Vector3(center.x, center.y, part.octant_lower_bound.z) \
				, Vector3(part.octant_upper_bound.x, part.octant_upper_bound.y, center.z)));
		part.children.push_back(octree_part.new(center, part.octant_upper_bound));
		for child : octree_part in part.children:
			if(child != null):
				divide_gridmap_octree_part(child);

func gen_arrays_for_octree(root : octree_part, vertices : PackedVector3Array, indices : PackedInt32Array) -> void:
	var depth : int = vertices.size()/8;
	#BOTTOM FACE VERTICES CLOCKWISE FROM SWD
	var south_west_down : Vector3 = root.octant_lower_bound;
	var north_west_down : Vector3 = Vector3(root.octant_lower_bound.x, root.octant_lower_bound.y, root.octant_upper_bound.z);
	var north_east_down : Vector3 = Vector3(root.octant_upper_bound.x, root.octant_lower_bound.y, root.octant_upper_bound.z);
	var south_east_down : Vector3 = Vector3(root.octant_upper_bound.x, root.octant_lower_bound.y,  root.octant_lower_bound.z)
	#TOP FACE VERTICES CLOCKWISE FROM SWU
	var south_west_up : Vector3 = Vector3(root.octant_lower_bound.x, root.octant_upper_bound.y, root.octant_lower_bound.z);
	var north_west_up : Vector3 = Vector3(root.octant_lower_bound.x, root.octant_upper_bound.y, root.octant_upper_bound.z);
	var north_east_up : Vector3 = root.octant_upper_bound;
	var south_east_up : Vector3 = Vector3(root.octant_upper_bound.x, root.octant_upper_bound.y,  root.octant_lower_bound.z)
	
	vertices.push_back(south_west_down);
	vertices.push_back(north_west_down);
	vertices.push_back(north_east_down);
	vertices.push_back(south_east_down);
	vertices.push_back(south_west_up);
	vertices.push_back(north_west_up);
	vertices.push_back(north_east_up);
	vertices.push_back(south_east_up);
	
	#BOTTOM FACE EDGES
	indices.push_back(0 + depth * 8);
	indices.push_back(1 + depth * 8);
	indices.push_back(1 + depth * 8);
	indices.push_back(2 + depth * 8);
	indices.push_back(2 + depth * 8);
	indices.push_back(3 + depth * 8);
	indices.push_back(3 + depth * 8);
	indices.push_back(0 + depth * 8);
	#TOP FACE EDGES
	indices.push_back(4 + depth * 8);
	indices.push_back(5 + depth * 8);
	indices.push_back(5 + depth * 8);
	indices.push_back(6 + depth * 8);
	indices.push_back(6 + depth * 8);
	indices.push_back(7 + depth * 8);
	indices.push_back(7 + depth * 8);
	indices.push_back(4 + depth * 8);
	#BETWEEN EDGES
	indices.push_back(0 + depth * 8);
	indices.push_back(4 + depth * 8);
	indices.push_back(1 + depth * 8);
	indices.push_back(5 + depth * 8);
	indices.push_back(2 + depth * 8);
	indices.push_back(6 + depth * 8);
	indices.push_back(3 + depth * 8);
	indices.push_back(7 + depth * 8);
	
	for child in root.children:
		if(child != null):
			gen_arrays_for_octree(child, vertices, indices);

func _get_property_list() -> Array[Dictionary]:
	var properties : Array[Dictionary];
	properties.append({
			"name": "display_octree",
			"type": TYPE_BOOL,
		});
	properties.append({
			"name": "grid_map",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_NODE_TYPE,
			"hint_string": "GridMap",
		});
	properties.append({
			"name": "grid_item_density",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "2, 3, 1, or_greater, hide_slider",
	});
	properties.append({
			"name": "custom_unit_octant",
			"type": TYPE_BOOL,
	});
	properties.append({
		"name": "relative_to_grid",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT | (int(not custom_unit_octant) * PROPERTY_USAGE_READ_ONLY),
	});
	properties.append({
		"name": "custom_lower_bound",
		"type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT | (int(not custom_unit_octant) * PROPERTY_USAGE_READ_ONLY),
	});
	properties.append({
		"name": "custom_upper_bound",
		"type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT | (int(not custom_unit_octant) * PROPERTY_USAGE_READ_ONLY),
	});
		
	return properties;
	
func _get(property: StringName) -> Variant:
	match property:
		"display_octree":
			return display_octree;
		"grid_map":
			return grid_map;
		"grid_item_density":
			return grid_item_density;
		"custom_unit_octant":
			return custom_unit_octant;
		"relative_to_grid":
			return relative_to_grid;
		"custom_lower_bound":
			return custom_lower_bound;
		"custom_upper_bound":
			return custom_upper_bound;
	return null;

func _set(property: StringName, value: Variant) -> bool:
	match property:
		"display_octree":
			display_octree = value;
			return true
		"grid_map":
			grid_map = value;
			return true
		"grid_item_density":
			grid_item_density = value;
			return true
		"custom_unit_octant":
			custom_unit_octant = value;
			return true
		"relative_to_grid":
			relative_to_grid = value;
			return true
		"custom_lower_bound":
			custom_lower_bound = value;
			return true
		"custom_upper_bound":
			custom_upper_bound = value;
			return true
	return false;
