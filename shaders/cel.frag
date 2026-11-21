// CEL SHADER™: flat toon colour bands + ink outlines, over the whole app.
// Used through ImageFilter.shader, so the engine fills in u_size (first vec2)
// and u_texture (first sampler) with what is being drawn underneath.
#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 u_size;      // set by the engine (physical pixels)
uniform float u_bands;    // number of light bands
uniform float u_thick;    // outline thickness in physical pixels
uniform sampler2D u_texture;

out vec4 frag_color;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float lumaAt(vec2 uv) {
  vec4 c = texture(u_texture, clamp(uv, vec2(0.0), vec2(1.0)));
  return luma(c.rgb);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  vec4 src = texture(u_texture, uv);
  if (src.a <= 0.0) {
    frag_color = vec4(0.0);
    return;
  }
  vec3 rgb = src.rgb / src.a; // un-premultiply

  // Toon bands: snap brightness to a few flat steps, keep the hue.
  float l = luma(rgb);
  float q = floor(l * u_bands + 0.5) / u_bands;
  vec3 toon = clamp(rgb * (q / max(l, 0.001)), 0.0, 1.0);
  // Comic-book punch: push colours away from grey.
  toon = clamp(mix(vec3(luma(toon)), toon, 1.25), 0.0, 1.0);

  // Ink outlines: Sobel on brightness.
  vec2 px = vec2(u_thick) / u_size;
  float tl = lumaAt(uv + px * vec2(-1.0, -1.0));
  float t  = lumaAt(uv + px * vec2( 0.0, -1.0));
  float tr = lumaAt(uv + px * vec2( 1.0, -1.0));
  float ml = lumaAt(uv + px * vec2(-1.0,  0.0));
  float mr = lumaAt(uv + px * vec2( 1.0,  0.0));
  float bl = lumaAt(uv + px * vec2(-1.0,  1.0));
  float b  = lumaAt(uv + px * vec2( 0.0,  1.0));
  float br = lumaAt(uv + px * vec2( 1.0,  1.0));
  float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
  float gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
  float edge = smoothstep(0.25, 0.55, length(vec2(gx, gy)));

  vec3 ink = vec3(0.06, 0.04, 0.10);
  vec3 outc = mix(toon, ink, edge);
  frag_color = vec4(outc * src.a, src.a);
}
