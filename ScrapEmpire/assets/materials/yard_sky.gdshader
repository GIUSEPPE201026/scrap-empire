shader_type sky;

uniform vec4 zenith_color : source_color = vec4(0.25,0.46,0.67,1.0);
uniform vec4 horizon_color : source_color = vec4(0.82,0.73,0.59,1.0);
uniform vec4 cloud_color : source_color = vec4(0.96,0.89,0.78,1.0);
uniform vec3 sun_direction = vec3(0.3,0.7,0.6);
uniform float daylight : hint_range(0.0,1.0) = 1.0;
uniform float world_seconds = 0.0;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;

float hash21(highp vec2 point) {
	highp float hashed=sin(dot(point,vec2(127.1,311.7)))*43758.5453;
	return fract(hashed);
}

float clouds(vec3 direction) {
	float height=max(direction.y,0.0);
	vec2 coordinates=direction.xz/(height+0.25)*0.2+vec2(world_seconds*0.00016,world_seconds*0.000055);
	float cloud=texture(cloud_noise,coordinates).r;
	return smoothstep(0.48,0.76,cloud)*smoothstep(0.02,0.20,height)*0.55;
}

vec3 background(vec3 direction, float density) {
	float height=max(direction.y,0.0);
	vec3 color=mix(horizon_color.rgb,zenith_color.rgb,pow(height,0.42));
	if (direction.y<0.0) {
		return mix(horizon_color.rgb,vec3(0.10,0.085,0.065),clamp(-direction.y*2.0,0.0,1.0));
	}
	color=mix(color,cloud_color.rgb,density);
	float sun=max(dot(direction,normalize(sun_direction)),0.0);
	float disc=smoothstep(cos(0.021),cos(0.014),sun);
	float halo=pow(sun,32.0)*0.13;
	color+=vec3(1.0,0.72,0.41)*(disc*1.8+halo)*daylight*(1.0-density*0.6);
	float night=1.0-daylight;
	vec2 stars=vec2(atan(direction.x,direction.z)/6.2831853,asin(clamp(direction.y,-1.0,1.0))/3.14159265)*vec2(512,256);
	float star=step(0.994,hash21(floor(stars)))*(1.0-smoothstep(0.0,0.18,length(fract(stars)-0.5)));
	color+=vec3(0.65,0.77,0.92)*star*night*smoothstep(0.08,0.30,height)*(1.0-density);
	float moon=max(dot(direction,-normalize(sun_direction)),0.0);
	color+=vec3(0.68,0.78,0.95)*smoothstep(cos(0.029),cos(0.024),moon)*night*(1.0-density);
	return color;
}

void sky() {
	vec3 direction=normalize(EYEDIR);
	if (AT_CUBEMAP_PASS) {
		COLOR=mix(horizon_color.rgb,zenith_color.rgb,pow(max(direction.y,0.0),0.42));
	} else {
		COLOR=background(direction,clouds(direction));
	}
}
