// Created by Justin Shrake - @j2rgb/2019
// Created in https://github.com/jshrake/grimoire
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// An artistic lens dispersion effect. This is not intended to be physically realistic.

// Resources:
// - https://web.archive.org/web/20061128135550/http://home.iitk.ac.in/~shankars/reports/dispersionraytrace.pdf
// - inspired by https://www.taylorpetrick.com/blog/post/dispersion-opengl

/**
 * Original:
 * https://www.shadertoy.com/view/wt2GDW
 */
 
// Comment to hide the lens ring
#define SHOW_RING

void mainImage(out vec4 fragColor, in vec2 fragCoord) 
{
    // Normalized device coordinates (0..1 in both directions)
    vec2 uv = fragCoord / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, uv);

    // We'll use uv in place of the old lens_uv
    vec2 lens_uv = uv;

    // A fixed lens center in the middle of the screen
    vec2 lens_pos = vec2(0.5, 0.5);

    // Distance from current fragment to the center
    vec2 lens_delta = lens_uv - lens_pos;
    float lens_dist = length(lens_delta);

    // We want the entire screen to be under the lens,
    // so choose a radius >= the farthest distance from the center to any corner.
    // For a screen of any aspect, setting lens_radius = 1.0 ensures coverage
    // in normalized 0..1 space.
    float lens_radius = 1.0;

    // "Zoom" amount of the lens
    float lens_zoom = 2.0;

    // Controls how we compute the fake spherical z component
    float lens_radius_fudge = clamp(iTime*iTime, 0.0,20.0);

    // Build a normal for the "spherical" lens surface
    float z_comp = lens_zoom * sqrt(lens_radius_fudge * lens_radius - lens_dist * lens_dist);
    vec3 lens_normal = normalize(vec3(lens_delta.xy, z_comp));

    // Light is coming in along -Z
    vec3 incident = normalize(vec3(0.0, 0.0, -1.0));
    
    // "Index of refraction" ratios of air (1.0) to inside of lens
    float eta_r = 1.0 / 1.15;
    float eta_y = 1.0 / 1.17;
    float eta_g = 1.0 / 1.19;
    float eta_c = 1.0 / 1.21;
    float eta_b = 1.0 / 1.23;
    float eta_v = 1.0 / 1.25;

    // Compute refraction vectors for multiple wavelengths
    vec2 refract_r = refract(incident, lens_normal, eta_r).xy;
    vec2 refract_y = refract(incident, lens_normal, eta_y).xy;
    vec2 refract_g = refract(incident, lens_normal, eta_g).xy;
    vec2 refract_c = refract(incident, lens_normal, eta_c).xy;
    vec2 refract_b = refract(incident, lens_normal, eta_b).xy;
    vec2 refract_v = refract(incident, lens_normal, eta_v).xy;

    // Original texture
    vec3 tex = texture(iChannel0, uv).rgb;

    // Colors offset by the refraction
    vec3 tex_r = texture(iChannel0, uv + refract_r).rgb;
    vec3 tex_y = texture(iChannel0, uv + refract_y).rgb;
    vec3 tex_g = texture(iChannel0, uv + refract_g).rgb;
    vec3 tex_c = texture(iChannel0, uv + refract_c).rgb;
    vec3 tex_b = texture(iChannel0, uv + refract_b).rgb;
    vec3 tex_v = texture(iChannel0, uv + refract_v).rgb;

    // The channel mixing (based on some color matrix trick to re-blend R, G, B)
    float r = tex_r.r * 0.5;
    float g = tex_g.g * 0.5;
    float b = tex_b.b * 0.5;
    float y = dot(vec3(2.0, 2.0, -1.0), tex_y) / 6.0;
    float c = dot(vec3(-1.0, 2.0, 2.0), tex_c) / 6.0;
    float v = dot(vec3(2.0, -1.0, 2.0), tex_v) / 6.0;

    float R = r + (2.0 * v + 2.0 * y - c) / 3.0;
    float G = g + (2.0 * y + 2.0 * c - v) / 3.0;
    float B = b + (2.0 * c + 2.0 * v - y) / 3.0;

    // Since we want the whole screen to have the lens effect, we simply use our
    // lens-based color. If you'd like a transition from normal -> lens, uncomment
    // the "mix" usage, but set lens_radius >= maximum screen distance so it's always '1'.
    //
    // vec3 color = mix(tex, vec3(R, G, B), step(lens_dist, lens_radius));
    // Because the entire screen is inside the lens, that step(...) is always 1.0 anyway:
    vec3 color = vec3(R, G, B);

    #ifdef SHOW_RING
    // If lens_radius is >= 1.0, the ring might be off-screen or very near the edges.
    // Feel free to adjust lens_radius to see or hide the ring.
    float ring = smoothstep(
        0.0, 
        2.0 / iResolution.y, 
        abs(length(lens_delta) - lens_radius) - 0.005
    );
    color *= ring;
    #endif
   
    float fade = clamp(-2.2 + iTime, 0.0,1.0);
    fragColor = mix(terminalColor, vec4(color, color.rgb+color.rgb+terminalColor.a*fade), 1.0-fade);
}
