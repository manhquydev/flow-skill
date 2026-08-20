// @ts-check
import { readFileSync } from 'node:fs';
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { satteri } from '@astrojs/markdown-satteri';
import { customHeadingIdPlugin } from './plugins/custom-heading-id.mjs';

const redirects = JSON.parse(
	readFileSync(new URL('./redirects.json', import.meta.url), 'utf8'),
);

// https://astro.build/config
export default defineConfig({
	site: 'https://flowskill.io.vn',
	redirects,
	markdown: {
		// Sätteri ignores markdown.remarkPlugins. Custom `{#id}` markers are
		// converted here so dest hashes in _redirects resolve to real HTML ids.
		processor: satteri({
			hastPlugins: [customHeadingIdPlugin],
		}),
	},
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
					label: 'Start',
					translations: { vi: 'Bắt đầu' },
					items: [
						{ label: 'Install and run', translations: { vi: 'Cài và chạy' }, slug: 'docs' },
					],
				},
				{
					label: 'Use',
					translations: { vi: 'Dùng' },
					items: [
						{ label: 'Everyday loop', translations: { vi: 'Vòng hằng ngày' }, slug: 'docs/how-to/use-chat-concierge' },
						{ label: 'Walk a full project', translations: { vi: 'Đi một dự án đủ' }, slug: 'docs/tutorials/first-greenfield-project' },
						{ label: 'Planning gates', translations: { vi: 'Cổng planning' }, slug: 'docs/explanation/stage-pipeline' },
						{ label: 'Cards and done-evidence', translations: { vi: 'Card và bằng chứng done' }, slug: 'docs/how-to/create-and-check-cards' },
						{ label: 'Existing repo', translations: { vi: 'Repo có sẵn' }, slug: 'docs/how-to/resume-mid-project' },
						{ label: 'If install breaks', translations: { vi: 'Cài hỏng thì sao' }, slug: 'docs/how-to/troubleshoot-install' },
					],
				},
				{
					label: 'More',
					translations: { vi: 'Thêm' },
					items: [
						{ label: 'How flow thinks', translations: { vi: 'flow nghĩ thế nào' }, slug: 'docs/explanation/what-is-flow' },
						{ label: 'When work must halt', translations: { vi: 'Khi việc phải dừng' }, slug: 'docs/explanation/auto-tiers-and-security-halts' },
						{ label: 'Commands', translations: { vi: 'Lệnh' }, slug: 'docs/reference/commands' },
						{ label: 'Glossary', translations: { vi: 'Thuật ngữ' }, slug: 'docs/reference/glossary' },
						{ label: 'Changelog', translations: { vi: 'Nhật ký thay đổi' }, slug: 'docs/reference/changelog' },
					],
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
