shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0);
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    float mask = smoothstep(progress, progress + 0.02, dist + 0.05);
    COLOR = vec4(color.rgb, mask);
}