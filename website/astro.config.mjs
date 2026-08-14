// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://flowskill.io.vn',
	integrations: [
		starlight({
			title: 'flow',
			defaultLocale: 'root',
			locales: {
				root: { label: 'English', lang: 'en' },
				vi: { label: 'Tiếng Việt', lang: 'vi' },
			},
			social: [
				{
					icon: 'github',
					label: 'GitHub',
					href: 'https://github.com/manhquydev/flow-skill',
				},
			],
			sidebar: [
				{
					label: 'Tutorials',
					translations: { vi: 'Hướng dẫn' },
					items: [{ autogenerate: { directory: 'docs/tutorials' } }],
				},
				{
					label: 'How-to',
					translations: { vi: 'Cách làm' },
					items: [{ autogenerate: { directory: 'docs/how-to' } }],
				},
				{
					label: 'Explanation',
					translations: { vi: 'Giải thích' },
					items: [{ autogenerate: { directory: 'docs/explanation' } }],
				},
				{
					label: 'Reference',
					translations: { vi: 'Tham chiếu' },
					items: [{ autogenerate: { directory: 'docs/reference' } }],
				},
			],
			customCss: [
				'./node_modules/@fontsource/big-shoulders-display/700.css',
				'./node_modules/@fontsource/big-shoulders-display/800.css',
				'./node_modules/@fontsource/archivo/400.css',
				'./node_modules/@fontsource/archivo/600.css',
				'./node_modules/@fontsource/archivo/700.css',
				'./node_modules/@fontsource/azeret-mono/500.css',
				'./src/styles/galley.css',
				'./src/styles/docs.css',
			],
			components: {
				SiteTitle: './src/overrides/SiteTitle.astro',
			},
		}),
	],
});
