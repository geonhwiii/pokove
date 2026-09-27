// @ts-check
import { defineConfig } from 'astro/config';

// Served from Vercel at https://pokove.vercel.app.
export default defineConfig({
  site: 'https://pokove.vercel.app',
  trailingSlash: 'ignore',
  devToolbar: { enabled: false },
  i18n: {
    defaultLocale: 'ko',
    locales: ['ko', 'en'],
    routing: { prefixDefaultLocale: false },
  },
});
