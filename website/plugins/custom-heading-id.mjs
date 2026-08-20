/**
 * Convert trailing `{#custom-id}` on headings into a real HTML `id`,
 * and strip the marker from visible heading text.
 *
 * Astro 7 + Starlight default to Sätteri. `markdown.remarkPlugins` do not
 * run on that processor (and GFM `{#id}` is printed as heading text).
 * This is a Sätteri hastPlugin — the engine-native equivalent of a remark
 * heading-id plugin. It must run before Starlight's heading-ids / autolink
 * plugins so TOC text is clean and autolink hrefs use the custom id.
 *
 * @returns {import('satteri').HastPluginDefinition}
 */
export function customHeadingIdPlugin() {
	const marker = /\s*\{#([A-Za-z0-9._:-]+)\}\s*$/;
	return {
		name: 'custom-heading-id',
		element: {
			filter: ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'],
			visit(node, ctx) {
				const text = ctx.textContent(node);
				const match = marker.exec(text);
				if (!match) return;
				const id = match[1];
				const last = lastTextDescendant(node);
				if (last && typeof last.value === 'string' && marker.test(last.value)) {
					const next = last.value.replace(marker, '');
					if (next.length === 0) ctx.removeNode(last);
					else ctx.replaceNode(last, { type: 'text', value: next });
					ctx.setProperty(node, 'id', id);
					return;
				}
				const stripped = text.replace(marker, '');
				return {
					type: 'element',
					tagName: node.tagName,
					properties: { ...(node.properties ?? {}), id },
					children: stripped ? [{ type: 'text', value: stripped }] : [],
				};
			},
		},
	};
}

/**
 * @param {import('hast').Nodes} node
 * @returns {import('hast').Text | null}
 */
function lastTextDescendant(node) {
	if (node.type === 'text') return node;
	const children = node.children;
	if (!Array.isArray(children) || children.length === 0) return null;
	for (let i = children.length - 1; i >= 0; i--) {
		const found = lastTextDescendant(children[i]);
		if (found) return found;
	}
	return null;
}
