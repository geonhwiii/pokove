// @ts-check
import { defineConfig } from 'astro/config';

// Served from Vercel at https://pokove.vercel.app.
export default defineConfig({
  site: 'https://pokove.vercel.app',
  trailingSlash: 'ignore',
  devToolbar: { enabled: false },
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'ko'],
    routing: { prefixDefaultLocale: false },
  },
});
