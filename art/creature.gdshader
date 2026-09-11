shader_type canvas_item;
render_mode unshaded;

uniform float motion_phase = 0.0;
uniform float gait_strength = 1.0;
uniform float slow_amount = 0.0;
uniform float hit_flash = 0.0;
uniform float dissolve = 0.0;
varying vec4 sprite_tint;

void vertex() {
 sprite_tint = COLOR;
}

void fragment() {
 vec2 uv = UV;
 float limbs = smoothstep(0.10, 0.32, abs(uv.x - 0.5));
 float side = uv.x < 0.5 ? 0.0 : 3.14159;
 uv.y += sin(motion_phase * 10.0 + uv.y * 18.0 + side) * 0.016 * limbs * gait_strength;
 uv.x += cos(motion_phase * 10.0 + uv.y * 14.0 + side) * 0.008 * limbs * gait_strength;
 vec4 pixel = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
 float coverage = smoothstep(0.025, 0.085, max(pixel.r, max(pixel.g, pixel.b)));
 float value = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
 vec3 frozen = vec3(0.20, 0.76, 1.0) * (0.30 + value * 1.2);
 pixel.rgb = min(pixel.rgb * 1.23, vec3(1.0));
 pixel.rgb = mix(pixel.rgb, frozen, slow_amount * 0.82);
 pixel.rgb = mix(pixel.rgb, vec3(1.0, 0.95, 0.82), hit_flash * 0.8);
 float edge = smoothstep(dissolve - 0.12, dissolve + 0.1, UV.y);
 COLOR = sprite_tint * vec4(pixel.rgb, pixel.a * coverage * mix(1.0, edge, step(0.001, dissolve)));
}
