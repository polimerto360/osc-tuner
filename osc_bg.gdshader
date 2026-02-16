shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}
uniform float ratio = 1.296;
uniform float r = 0.12;
uniform float shading_strength;
void fragment() {

	float width = 0.5;
	float height = 0.5;

	vec2 point_ul = vec2(r, r);
	vec2 point_ur = vec2(ratio - r, r);
	vec2 point_bl = vec2(r, 1.0 - r);
	vec2 point_br = vec2(ratio - r, 1.0 - r);
	float x = UV.x * ratio;
	float y = UV.y;
	bool corner = ((x - point_ul.x) * (x - point_ul.x) + (y - point_ul.y) * (y - point_ul.y) < r * r) || ((x - point_ur.x) * (x - point_ur.x) + (y - point_ur.y) * (y - point_ur.y) < r * r) || ((x - point_bl.x) * (x - point_bl.x) + (y - point_bl.y) * (y - point_bl.y) < r * r) || ((x - point_br.x) * (x - point_br.x) + (y - point_br.y) * (y - point_br.y) < r * r);
	if(abs(x - 0.5*ratio) < width*ratio - r || abs(y - 0.5) < height - r || corner) {
		COLOR = COLOR - vec4(1., 1., 1., 0.7) * abs(0.5-UV.y) * shading_strength;
	} else {
		COLOR.a = 0.0;
	}
	//COLOR += texture(backbuffer, SCREEN_UV);
}