export const repo = 'https://github.com/geonhwiii/pokove';
/** Always the newest release's disk image, built by `scripts/package.sh`. */
export const downloadURL = `${repo}/releases/latest/download/pokove.dmg`;
/** The site's download page, which starts `downloadURL`. Its page views count downloads in
 *  Vercel Web Analytics, which has no custom events on the Hobby plan. */
export const downloadPage = (lang: 'en' | 'ko') => url(lang === 'ko' ? 'download' : 'en/download');
export const releasesURL = `${repo}/releases`;

/** A path under the site's base. */
export function url(path = ''): string {
  const base = import.meta.env.BASE_URL.replace(/\/$/, '');
  return `${base}/${path.replace(/^\//, '')}`;
}

/** Sprites load from PokéAPI's repository at runtime, as in the app. None are in this site. */
const sprites = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites';
export const sprite = {
  icon: (id: number) => `${sprites}/pokemon/versions/generation-vii/icons/${id}.png`,
  front: (id: number) => `${sprites}/pokemon/versions/generation-v/black-white/animated/${id}.gif`,
  back: (id: number) => `${sprites}/pokemon/versions/generation-v/black-white/animated/back/${id}.gif`,
  item: (name: string) => `${sprites}/items/${name}.png`,
  badge: (n: number) => `${sprites}/badges/${n}.png`,
};
