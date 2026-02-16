shader_type canvas_item;

uniform float strength;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec4 color = vec4(1, 1, 1, 0);
	COLOR = COLOR - color * vec4(UV.y, UV.y, UV.y, 0) * strength;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
