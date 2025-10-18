extends Node
class_name ShapeRecognizer

## Shape recognition system for detecting circles and triangles from point arrays
## Uses geometric analysis to classify drawn shapes

enum ShapeType {
	UNKNOWN,
	CIRCLE,
	TRIANGLE
}

@export_group("Circle Detection")
@export var circle_variance_threshold: float = 0.25  ## Max variance in radius (0-1, lower = stricter)
@export var circle_closedness_threshold: float = 80.0  ## Max distance between start and end points
@export var circle_min_points: int = 10  ## Minimum points needed for circle detection

@export_group("Triangle Detection")
@export var triangle_angle_cluster_threshold: float = 30.0  ## Max angle within a cluster (degrees)
@export var triangle_closedness_threshold: float = 80.0  ## Max distance between start and end points
@export var triangle_min_points: int = 6  ## Minimum points needed for triangle detection


## Detect what shape the given points represent
func detect_shape(points: Array[Vector2]) -> ShapeType:
	if points.size() < 3:
		return ShapeType.UNKNOWN

	# Try circle detection first (usually more specific)
	if is_circle(points):
		return ShapeType.CIRCLE

	# Try triangle detection
	if is_triangle(points):
		return ShapeType.TRIANGLE

	return ShapeType.UNKNOWN


## Check if points form a circle using centroid variance method
func is_circle(points: Array[Vector2]) -> bool:
	if points.size() < circle_min_points:
		return false

	# Check if path is closed (start and end are close)
	var start_point = points[0]
	var end_point = points[points.size() - 1]
	if start_point.distance_to(end_point) > circle_closedness_threshold:
		return false

	# Calculate centroid
	var centroid = calculate_centroid(points)

	# Calculate distances from centroid
	var distances: Array[float] = []
	for point in points:
		distances.append(point.distance_to(centroid))

	# Calculate mean distance (average radius)
	var mean_distance = 0.0
	for dist in distances:
		mean_distance += dist
	mean_distance /= distances.size()

	if mean_distance < 10.0:  # Too small to be intentional
		return false

	# Calculate variance in distances
	var variance = 0.0
	for dist in distances:
		var diff = dist - mean_distance
		variance += diff * diff
	variance /= distances.size()

	# Normalize variance by mean (coefficient of variation)
	var normalized_variance = sqrt(variance) / mean_distance

	# Check if variance is low enough
	if normalized_variance > circle_variance_threshold:
		return false

	return true


## Check if points form a triangle using angle clustering
func is_triangle(points: Array[Vector2]) -> bool:
	if points.size() < triangle_min_points:
		return false

	# Check if path is closed (start and end are close)
	var start_point = points[0]
	var end_point = points[points.size() - 1]
	if start_point.distance_to(end_point) > triangle_closedness_threshold:
		return false

	# Calculate angles between consecutive points
	var angles: Array[float] = []

	for i in range(points.size()):
		var prev_idx = (i - 1 + points.size()) % points.size()
		var next_idx = (i + 1) % points.size()

		var prev_point = points[prev_idx]
		var curr_point = points[i]
		var next_point = points[next_idx]

		# Calculate angle at current point
		var angle = calculate_angle_at_point(prev_point, curr_point, next_point)
		angles.append(angle)

	# Find angle jumps (where angle changes significantly)
	var jumps = find_angle_jumps(angles)

	# A triangle should have 3 significant angle jumps (the corners)
	if jumps.size() >= 2 and jumps.size() <= 4:  # Allow some tolerance
		return true

	return false


## Calculate the centroid (center of mass) of points
func calculate_centroid(points: Array[Vector2]) -> Vector2:
	var sum = Vector2.ZERO
	for point in points:
		sum += point
	return sum / points.size()


## Calculate the angle at a point given its neighbors
func calculate_angle_at_point(prev: Vector2, curr: Vector2, next: Vector2) -> float:
	var vec1 = (prev - curr).normalized()
	var vec2 = (next - curr).normalized()

	# Calculate angle between vectors
	var dot = vec1.dot(vec2)
	dot = clamp(dot, -1.0, 1.0)  # Prevent floating point errors

	var angle = rad_to_deg(acos(dot))
	return angle


## Find significant jumps in the angle sequence (triangle corners)
func find_angle_jumps(angles: Array[float]) -> Array[int]:
	var jumps: Array[int] = []

	if angles.size() < 3:
		return jumps

	# Calculate differences between consecutive angles
	var differences: Array[float] = []
	for i in range(angles.size()):
		var next_idx = (i + 1) % angles.size()
		var diff = abs(angles[next_idx] - angles[i])
		differences.append(diff)

	# Find mean difference
	var mean_diff = 0.0
	for diff in differences:
		mean_diff += diff
	mean_diff /= differences.size()

	# Find points where difference is significantly higher than average
	# These are likely corners
	for i in range(differences.size()):
		if differences[i] > mean_diff + triangle_angle_cluster_threshold:
			jumps.append(i)

	# Merge nearby jumps (within a few points of each other)
	var merged_jumps: Array[int] = []
	var skip_until = -1

	for i in range(jumps.size()):
		if i <= skip_until:
			continue

		var current_jump = jumps[i]
		merged_jumps.append(current_jump)

		# Skip any jumps within 3 points
		for j in range(i + 1, jumps.size()):
			if jumps[j] - current_jump <= 3:
				skip_until = j
			else:
				break

	return merged_jumps
