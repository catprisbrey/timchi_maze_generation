@icon("res://addons/timchi_maze_generation/maze.svg")
@tool
class_name PackedMaze3D
extends Node3D

@export_group("Maze")
@export var randomize_at_ready : bool = false
@export_range(1, 100, 1, "or_greater") var maze_width := 4:
	set(value): maze_width = value; draw_maze()
				
@export_range(1, 100, 1, "or_greater") var maze_height := 4:
	set(value): maze_height = value; draw_maze()
	
@export_range(0.0, 1.0, 0.05) var linearity := 0.75:
	set(value): linearity = value; draw_maze()
	
@export var seed := 0:
	set(value): seed = value; draw_maze()

@export var generate_navmesh := true

@export_group("Cell Scenes")
@export var dead_end_scenes: Array[PackedScene] = []
@export var hallway_scenes: Array[PackedScene] = []
@export var corner_scenes: Array[PackedScene] = []
@export var junction_scenes: Array[PackedScene] = []
@export var all_way_scenes: Array[PackedScene] = []

@export_group("Scene Settings")
@export var cell_size := Vector3(2.0, 2.0, 2.0)  ## Size of each cell for positioning
@export_range(0, 270, 90) var rotation_adjustment: int = 0
@export var randomize_scene_selection := true  ## Pick random scene variant for each cell

@onready var maze: Maze = Maze.new(maze_width, maze_height, linearity, seed)

var spawned_instances: Array[Node3D] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func draw_maze():
	maze = Maze.new(maze_width, maze_height, linearity, seed)
	maze.generate_maze()
	
	# Initialize RNG with the same seed for consistent scene selection
	rng.seed = seed
	
	if not has_node("Navigation"):
		return
	
	clear_maze()
	
	for item: Vector2i in maze.maze:
		var mi = maze.maze[item]
		var t = mi.get_type()
		var scene_array: Array[PackedScene] = []
		
		match t:
			Cell.DEAD_END: scene_array = dead_end_scenes
			Cell.CORNER: scene_array = corner_scenes
			Cell.HALLWAY: scene_array = hallway_scenes
			Cell.JUNCTION: scene_array = junction_scenes
			_: scene_array = all_way_scenes
		
		if scene_array.is_empty():
			continue
		
		# Pick a random scene from the array, or just use the first one
		var scene_to_spawn: PackedScene
		if randomize_scene_selection && scene_array.size() > 1:
			scene_to_spawn = scene_array[rng.randi() % scene_array.size()]
		else:
			scene_to_spawn = scene_array[0]
		
		if scene_to_spawn == null:
			continue
		
		var instance = scene_to_spawn.instantiate()
		if instance is Node3D:
			# Position the instance
			instance.position = Vector3(
				mi.location.x * cell_size.x,
				0,
				mi.location.y * cell_size.z
			)
			
			# Rotate the instance
			var rotation_rad = mi.get_rotation() + deg_to_rad(rotation_adjustment)
			instance.rotation.y = rotation_rad
			
			# Add as child of Navigation node so navmesh can detect it
			$Navigation.add_child(instance)
			if Engine.is_editor_hint():
				instance.owner = get_tree().edited_scene_root
			
			spawned_instances.append(instance)
	
	# Wait for nodes to be ready before baking navmesh
	if generate_navmesh and has_node("Navigation"):
		# Defer baking to next frame so all nodes are processed
		await get_tree().process_frame
		if has_node("Navigation"):
			$Navigation.bake_navigation_mesh()
	elif has_node("Navigation"):
		$Navigation.navigation_mesh.clear()

func clear_maze():
	# Remove all previously spawned instances
	for instance in spawned_instances:
		if is_instance_valid(instance):
			instance.queue_free()
	spawned_instances.clear()

func _ready():
	# Create Navigation node if it doesn't exist
	if not has_node("Navigation"):
		var nav_region = NavigationRegion3D.new()
		nav_region.name = "Navigation"
		nav_region.navigation_mesh = NavigationMesh.new()
		add_child(nav_region)
		if Engine.is_editor_hint():
			nav_region.owner = get_tree().edited_scene_root
	
	if randomize_at_ready:
		randomize()
		seed = randi_range(0,1000)
	#else:
		#draw_maze()
	add_to_group("timchi_maze")

func _exit_tree():
	clear_maze()
