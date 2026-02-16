// =====================================================
// WebDavXmlParser.ets - Minimal WebDAV PROPFIND XML helpers
//
// Purpose:
// - Parse common fields from WebDAV responses without heavy XML libs.
// - Works for most DAV servers (Jianguoyun, Nextcloud...) that return
//   multistatus with <d:response> elements.
//
// Notes:
// - This is a best-effort parser. It intentionally keeps logic simple.
// - If you hit incompatibilities with a specific WebDAV server, adjust
//   the regex patterns here.
// =====================================================

export interface WebDavResourceMeta {
  href: string;
  etag: string;
  lastModified: string;
}

function matchFirst(xml: string, re: RegExp): string {
  const m = xml.match(re);
  if (m === null || m.length < 2) return '';
  return (m[1] ?? '').trim();
}

export function parsePropfindMeta(xml: string): WebDavResourceMeta {
  // Single resource meta
  const href = matchFirst(xml, /<[^>]*href[^>]*>([^<]+)<\/[\s\S]*?href>/i);
  const etag = matchFirst(xml, /<[^>]*getetag[^>]*>([^<]*)<\/[\s\S]*?getetag>/i);
  const lastModified = matchFirst(xml, /<[^>]*getlastmodified[^>]*>([^<]*)<\/[\s\S]*?getlastmodified>/i);
  return { href, etag, lastModified };
}

export function parsePropfindList(xml: string): WebDavResourceMeta[] {
  // Extract each <d:response>...</d:response>
  const out: WebDavResourceMeta[] = [];
  const re = /<[^>]*response[^>]*>([\s\S]*?)<\/[\s\S]*?response>/ig;
  let m: RegExpExecArray | null;
  // eslint-disable-next-line no-cond-assign
  while ((m = re.exec(xml)) !== null) {
    const chunk = m[1] ?? '';
    const meta = parsePropfindMeta(chunk);
    if (meta.href.length > 0) {
      out.push(meta);
    }
  }
  return out;
}
