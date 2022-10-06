extends Camera2D

func camera_following(target_node):
	var x_sum = 0
	var y_sum = 0
	
	for tile in target_node.coord_tiles:
		x_sum += tile[0]
		y_sum += tile[1]
	
	var x_average = x_sum/target_node.coord_tiles.size()
	var y_average = y_sum/target_node.coord_tiles.size()
	
	var world_coord = target_node.map_to_world(Vector2(x_average, y_average+1))
	world_coord[0] += 50
	
	set_global_position (world_coord)
