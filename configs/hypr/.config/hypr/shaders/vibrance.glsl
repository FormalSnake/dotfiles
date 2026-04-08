#version 320 es
precision mediump float;

uniform sampler2D tex;
in vec2 v_texcoord;
out vec4 fragColor;

// Adjust this value: 1.0 = no change, >1.0 = more vibrant
const float saturation = 1.2;

void main() {
    vec4 color = texture(tex, v_texcoord);
    float gray = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 saturated = mix(vec3(gray), color.rgb, saturation);
    fragColor = vec4(saturated, color.a);
}
