shader_type canvas_item;

uniform float ratio = 1.296;
uniform float r = 0.12;
uniform float sy = 0.12;


float hue2rgb(float f1, float f2, float hue) {
    if (hue < 0.0)
        hue += 1.0;
    else if (hue > 1.0)
        hue -= 1.0;
    float res;
    if ((6.0 * hue) < 1.0)
        res = f1 + (f2 - f1) * 6.0 * hue;
    else if ((2.0 * hue) < 1.0)
        res = f2;
    else if ((3.0 * hue) < 2.0)
        res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
    else
        res = f1;
    return res;
}

vec3 hsl2rgb(vec3 hsl) {
    vec3 rgb;
    
    if (hsl.y == 0.0) {
        rgb = vec3(hsl.z); // Luminance
    } else {
        float f2;
        
        if (hsl.z < 0.5)
            f2 = hsl.z * (1.0 + hsl.y);
        else
            f2 = hsl.z + hsl.y - hsl.y * hsl.z;
            
        float f1 = 2.0 * hsl.z - f2;
        
        rgb.r = hue2rgb(f1, f2, hsl.x + (1.0/3.0));
        rgb.g = hue2rgb(f1, f2, hsl.x);
        rgb.b = hue2rgb(f1, f2, hsl.x - (1.0/3.0));
    }   
    return rgb;
}

vec3 hsl2rgb(float h, float s, float l) {
    return hsl2rgb(vec3(h, s, l));
}

bool visible(vec2 uv) {
	float width = 0.5;
	float height = 0.5;

	vec2 point_ul = vec2(r, r);
	vec2 point_ur = vec2(ratio - r, r);
	vec2 point_bl = vec2(r, 1.0 - r);
	vec2 point_br = vec2(ratio - r, 1.0 - r);
	float x = uv.x * ratio;
	float y = uv.y;
	bool corner = ((x - point_ul.x) * (x - point_ul.x) + (y - point_ul.y) * (y - point_ul.y) < r * r) || ((x - point_ur.x) * (x - point_ur.x) + (y - point_ur.y) * (y - point_ur.y) < r * r) || ((x - point_bl.x) * (x - point_bl.x) + (y - point_bl.y) * (y - point_bl.y) < r * r) || ((x - point_br.x) * (x - point_br.x) + (y - point_br.y) * (y - point_br.y) < r * r);
	return abs(x - 0.5*ratio) < width*ratio - r || abs(y - 0.5) < height - r || corner;
}
void fragment() {
	
	if(visible(UV) && COLOR.a > 0.) {
		COLOR.rgb = hsl2rgb(UV.x * 0.1 + 0.6 + sin(TIME/5.)/6., 1., 0.5);
	} else {
		COLOR = vec4(0., 0., 0., 0.);
	}
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
