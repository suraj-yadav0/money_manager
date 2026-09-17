export const ColorSchemes = [
  {
    id: 'dark',
    name: 'Obsidian Minimal',
    mode: 'dark',
    badge: 'Dark',
    description: 'Monochrome carbon slate with crisp solid white accents',
    primary: '#FFFFFF',
    surface: '#111215',
    bg: '#090A0C',
    palette: ['#FFFFFF', '#E2E8F0', '#CBD5E1', '#94A3B8', '#64748B', '#475569', '#334155']
  },
  {
    id: 'light',
    name: 'Studio Light',
    mode: 'light',
    badge: 'Light',
    description: 'Clean architectural paper white with deep obsidian ink',
    primary: '#0F172A',
    surface: '#F8FAFC',
    bg: '#FFFFFF',
    palette: ['#0F172A', '#334155', '#475569', '#64748B', '#94A3B8', '#CBD5E1', '#E2E8F0']
  },
  {
    id: 'emerald',
    name: 'Alpine Emerald',
    mode: 'dark',
    badge: 'Dark',
    description: 'Deep forest noir with luminous mint and emerald glow',
    primary: '#10B981',
    surface: '#0C1A15',
    bg: '#060F0C',
    palette: ['#10B981', '#34D399', '#6EE7B7', '#059669', '#047857', '#A7F3D0', '#D1FAE5']
  },
  {
    id: 'sapphire',
    name: 'Midnight Cobalt',
    mode: 'dark',
    badge: 'Dark',
    description: 'Oceanic abyss with electric sapphire and cyber azure',
    primary: '#38BDF8',
    surface: '#0C1527',
    bg: '#060B14',
    palette: ['#38BDF8', '#60A5FA', '#818CF8', '#0284C7', '#2563EB', '#BAE6FD', '#E0F2FE']
  },
  {
    id: 'amethyst',
    name: 'Cyber Violet',
    mode: 'dark',
    badge: 'Dark',
    description: 'Twilight obsidian with vibrant amethyst and neon lilac',
    primary: '#A855F7',
    surface: '#140E24',
    bg: '#0B0714',
    palette: ['#A855F7', '#C084FC', '#E879F9', '#7E22CE', '#9333EA', '#E9D5FF', '#F3E8FF']
  },
  {
    id: 'amber',
    name: 'Solar Gold',
    mode: 'dark',
    badge: 'Dark',
    description: 'Warm espresso charcoal with liquid gold and amber accents',
    primary: '#F59E0B',
    surface: '#19140D',
    bg: '#0E0B07',
    palette: ['#F59E0B', '#FBBF24', '#FCD34D', '#D97706', '#B45309', '#FDE68A', '#FEF3C7']
  },
  {
    id: 'rose',
    name: 'Crimson Noir',
    mode: 'dark',
    badge: 'Dark',
    description: 'Velvet charcoal with luxury ruby and rose accents',
    primary: '#F43F5E',
    surface: '#1B0D13',
    bg: '#0F070A',
    palette: ['#F43F5E', '#FB7185', '#FDA4AF', '#E11D48', '#BE123C', '#FECDD3', '#FFE4E6']
  },
  {
    id: 'nordic',
    name: 'Nordic Mist',
    mode: 'light',
    badge: 'Light',
    description: 'Frosted titanium silver with arctic steel and royal blue',
    primary: '#2563EB',
    surface: '#FFFFFF',
    bg: '#F4F7FB',
    palette: ['#2563EB', '#3B82F6', '#60A5FA', '#1D4ED8', '#1E40AF', '#93C5FD', '#BFDBFE']
  }
];

export function getTheme(id) {
  return ColorSchemes.find(s => s.id === id) || ColorSchemes[0];
}

export function isLightTheme(themeId) {
  const scheme = getTheme(themeId);
  return scheme ? scheme.mode === 'light' : false;
}

export function getThemePalette(themeId) {
  const scheme = getTheme(themeId);
  return scheme ? scheme.palette : ColorSchemes[0].palette;
}

export function hexToRgba(hex, alpha = 1) {
  if (!hex) return `rgba(255, 255, 255, ${alpha})`;
  let clean = hex.replace('#', '').trim();
  if (clean.length === 3) {
    clean = clean.split('').map(c => c + c).join('');
  }
  const num = parseInt(clean, 16);
  if (isNaN(num)) return `rgba(255, 255, 255, ${alpha})`;
  const r = (num >> 16) & 255;
  const g = (num >> 8) & 255;
  const b = num & 255;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}
