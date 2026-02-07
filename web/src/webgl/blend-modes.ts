export const BLEND_MODE_MAP: Record<string, number> = {
  passThrough: 0,
  normal: 0,
  dissolve: 0,
  darken: 4,
  multiply: 1,
  colorBurn: 7,
  linearBurn: 12,
  darkerColor: 4,
  lighten: 5,
  screen: 2,
  colorDodge: 6,
  linearDodge: 13,
  lighterColor: 5,
  overlay: 3,
  softLight: 8,
  hardLight: 9,
  vividLight: 9,
  linearLight: 9,
  pinLight: 5,
  hardMix: 9,
  difference: 10,
  exclusion: 11,
  subtract: 14,
  divide: 15,
  hue: 16,
  saturation: 17,
  color: 18,
  luminosity: 19,
};

export function getBlendModeId(mode: string): number {
  // Convert PSD blend mode name to shader ID
  // camelCase the mode name for lookup
  const key = mode.replace(/\s+/g, "");
  const lowerKey = key.charAt(0).toLowerCase() + key.slice(1);
  return BLEND_MODE_MAP[lowerKey] ?? 0;
}
