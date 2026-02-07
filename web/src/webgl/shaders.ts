export const BLIT_VERTEX = `#version 300 es
in vec2 a_position;
in vec2 a_texcoord;
uniform mat3 u_viewMatrix;
uniform mat3 u_modelMatrix;
out vec2 v_texcoord;

void main() {
  vec3 pos = u_viewMatrix * u_modelMatrix * vec3(a_position, 1.0);
  gl_Position = vec4(pos.xy, 0.0, 1.0);
  v_texcoord = a_texcoord;
}
`;

export const BLIT_FRAGMENT = `#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D u_texture;
uniform bool u_useChecker;
uniform float u_opacity;
out vec4 fragColor;

const vec4 CHECKER_A = vec4(0.22, 0.22, 0.22, 1.0);
const vec4 CHECKER_B = vec4(0.18, 0.18, 0.18, 1.0);

void main() {
  vec4 tex = texture(u_texture, v_texcoord);
  tex.a *= u_opacity;
  if (u_useChecker) {
    // Checkerboard for transparency
    vec2 fragCoord = gl_FragCoord.xy;
    float checker = mod(floor(fragCoord.x / 8.0) + floor(fragCoord.y / 8.0), 2.0);
    vec4 bg = mix(CHECKER_A, CHECKER_B, checker);
    // Blend texture over checkerboard using straight alpha
    fragColor = vec4(
      tex.rgb * tex.a + bg.rgb * (1.0 - tex.a),
      1.0
    );
  } else {
    // Pass through with alpha for overlay blending
    fragColor = tex;
  }
}
`;

export const OVERLAY_VERTEX = `#version 300 es
in vec2 a_position;
uniform mat3 u_viewMatrix;
uniform vec4 u_rect;  // left, top, right, bottom in document coords
uniform vec2 u_docSize;

void main() {
  // Map a_position from -1..1 to the rect in document coords
  float x = mix(u_rect.x, u_rect.z, a_position.x * 0.5 + 0.5);
  float y = mix(u_rect.y, u_rect.w, a_position.y * 0.5 + 0.5);

  // Convert document coords to NDC (-1..1)
  float ndcX = (x / u_docSize.x) * 2.0 - 1.0;
  float ndcY = 1.0 - (y / u_docSize.y) * 2.0;

  vec3 pos = u_viewMatrix * vec3(ndcX, ndcY, 1.0);
  gl_Position = vec4(pos.xy, 0.0, 1.0);
}
`;

export const OVERLAY_FRAGMENT = `#version 300 es
precision highp float;
uniform vec4 u_color;
out vec4 fragColor;

void main() {
  fragColor = u_color;
}
`;

export const COMPOSITE_VERTEX = `#version 300 es
in vec2 a_position;
in vec2 a_texcoord;
uniform mat3 u_modelMatrix;
out vec2 v_texcoord;
out vec2 v_dstcoord;

void main() {
  vec3 pos = u_modelMatrix * vec3(a_position, 1.0);
  gl_Position = vec4(pos.xy, 0.0, 1.0);
  v_texcoord = a_texcoord;
  // Map from clip space to texture coords for destination sampling
  v_dstcoord = pos.xy * 0.5 + 0.5;
}
`;

export const COMPOSITE_FRAGMENT = `#version 300 es
precision highp float;
in vec2 v_texcoord;
in vec2 v_dstcoord;
uniform sampler2D u_srcTexture;
uniform sampler2D u_dstTexture;
uniform int u_blendMode;
uniform float u_opacity;
out vec4 fragColor;

// Blend mode functions
vec3 blendNormal(vec3 s, vec3 d) { return s; }
vec3 blendMultiply(vec3 s, vec3 d) { return s * d; }
vec3 blendScreen(vec3 s, vec3 d) { return s + d - s * d; }

float overlayComponent(float s, float d) {
  return d < 0.5 ? 2.0 * s * d : 1.0 - 2.0 * (1.0 - s) * (1.0 - d);
}
vec3 blendOverlay(vec3 s, vec3 d) {
  return vec3(overlayComponent(s.r, d.r), overlayComponent(s.g, d.g), overlayComponent(s.b, d.b));
}

vec3 blendDarken(vec3 s, vec3 d) { return min(s, d); }
vec3 blendLighten(vec3 s, vec3 d) { return max(s, d); }

float colorDodgeComponent(float s, float d) {
  if (d == 0.0) return 0.0;
  if (s >= 1.0) return 1.0;
  return min(1.0, d / (1.0 - s));
}
vec3 blendColorDodge(vec3 s, vec3 d) {
  return vec3(colorDodgeComponent(s.r, d.r), colorDodgeComponent(s.g, d.g), colorDodgeComponent(s.b, d.b));
}

float colorBurnComponent(float s, float d) {
  if (d >= 1.0) return 1.0;
  if (s == 0.0) return 0.0;
  return 1.0 - min(1.0, (1.0 - d) / s);
}
vec3 blendColorBurn(vec3 s, vec3 d) {
  return vec3(colorBurnComponent(s.r, d.r), colorBurnComponent(s.g, d.g), colorBurnComponent(s.b, d.b));
}

float softLightComponent(float s, float d) {
  if (s <= 0.5) {
    return d - (1.0 - 2.0 * s) * d * (1.0 - d);
  } else {
    float g = d <= 0.25 ? ((16.0 * d - 12.0) * d + 4.0) * d : sqrt(d);
    return d + (2.0 * s - 1.0) * (g - d);
  }
}
vec3 blendSoftLight(vec3 s, vec3 d) {
  return vec3(softLightComponent(s.r, d.r), softLightComponent(s.g, d.g), softLightComponent(s.b, d.b));
}

float hardLightComponent(float s, float d) {
  return s < 0.5 ? 2.0 * s * d : 1.0 - 2.0 * (1.0 - s) * (1.0 - d);
}
vec3 blendHardLight(vec3 s, vec3 d) {
  return vec3(hardLightComponent(s.r, d.r), hardLightComponent(s.g, d.g), hardLightComponent(s.b, d.b));
}

vec3 blendDifference(vec3 s, vec3 d) { return abs(s - d); }
vec3 blendExclusion(vec3 s, vec3 d) { return s + d - 2.0 * s * d; }
vec3 blendLinearBurn(vec3 s, vec3 d) { return max(s + d - 1.0, vec3(0.0)); }
vec3 blendLinearDodge(vec3 s, vec3 d) { return min(s + d, vec3(1.0)); }
vec3 blendSubtract(vec3 s, vec3 d) { return max(d - s, vec3(0.0)); }
vec3 blendDivide(vec3 s, vec3 d) {
  return vec3(
    s.r > 0.0 ? min(1.0, d.r / s.r) : 1.0,
    s.g > 0.0 ? min(1.0, d.g / s.g) : 1.0,
    s.b > 0.0 ? min(1.0, d.b / s.b) : 1.0
  );
}

// HSL helpers for Hue/Saturation/Color/Luminosity
float luminance(vec3 c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b; }
vec3 clipColor(vec3 c) {
  float l = luminance(c);
  float mn = min(min(c.r, c.g), c.b);
  float mx = max(max(c.r, c.g), c.b);
  if (mn < 0.0) c = l + (c - l) * l / (l - mn);
  if (mx > 1.0) c = l + (c - l) * (1.0 - l) / (mx - l);
  return c;
}
vec3 setLuminance(vec3 c, float l) {
  float d = l - luminance(c);
  return clipColor(c + d);
}
float saturation(vec3 c) { return max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b); }

vec3 applyBlendMode(vec3 s, vec3 d, int mode) {
  // 0=Normal, 1=Multiply, 2=Screen, 3=Overlay, 4=Darken, 5=Lighten
  // 6=ColorDodge, 7=ColorBurn, 8=SoftLight, 9=HardLight
  // 10=Difference, 11=Exclusion, 12=LinearBurn, 13=LinearDodge
  // 14=Subtract, 15=Divide, 16=Hue, 17=Saturation, 18=Color, 19=Luminosity
  if (mode == 1) return blendMultiply(s, d);
  if (mode == 2) return blendScreen(s, d);
  if (mode == 3) return blendOverlay(s, d);
  if (mode == 4) return blendDarken(s, d);
  if (mode == 5) return blendLighten(s, d);
  if (mode == 6) return blendColorDodge(s, d);
  if (mode == 7) return blendColorBurn(s, d);
  if (mode == 8) return blendSoftLight(s, d);
  if (mode == 9) return blendHardLight(s, d);
  if (mode == 10) return blendDifference(s, d);
  if (mode == 11) return blendExclusion(s, d);
  if (mode == 12) return blendLinearBurn(s, d);
  if (mode == 13) return blendLinearDodge(s, d);
  if (mode == 14) return blendSubtract(s, d);
  if (mode == 15) return blendDivide(s, d);
  if (mode == 16) return setLuminance(s, luminance(d)); // Hue (simplified)
  if (mode == 17) return setLuminance(d, luminance(d)); // Saturation (simplified)
  if (mode == 18) return setLuminance(s, luminance(d)); // Color
  if (mode == 19) return setLuminance(d, luminance(s)); // Luminosity
  return s; // Normal / fallback
}

void main() {
  vec4 src = texture(u_srcTexture, v_texcoord);
  vec4 dst = texture(u_dstTexture, v_dstcoord);

  // Apply opacity
  float srcA = src.a * u_opacity;

  if (srcA < 0.001) {
    fragColor = dst;
    return;
  }

  // Apply blend mode
  vec3 blended = applyBlendMode(src.rgb, dst.rgb, u_blendMode);

  // Porter-Duff source-over
  float outA = srcA + dst.a * (1.0 - srcA);
  vec3 outRGB;
  if (outA > 0.001) {
    outRGB = (blended * srcA + dst.rgb * dst.a * (1.0 - srcA)) / outA;
  } else {
    outRGB = vec3(0.0);
  }

  fragColor = vec4(outRGB, outA);
}
`;
