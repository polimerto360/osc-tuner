shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}
uniform sampler2D prev_frame;
uniform float feedback = 0.9;

void fragment() {
	vec4 current = texture(TEXTURE, UV);      // from ViewportA
    vec4 previous = texture(prev_frame, UV);  // from last frame


    COLOR = mix(current, previous, feedback);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
