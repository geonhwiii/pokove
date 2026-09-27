export const repo = 'https://github.com/geonhwiii/pokove';
/** Always the newest release's zip, built by `scripts/package.sh`. */
export const downloadURL = `${repo}/releases/latest/download/pokove.zip`;
export const releasesURL = `${repo}/releases`;
export const version = '1.0';

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
