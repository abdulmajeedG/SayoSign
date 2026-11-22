// SayoSign helper Worker (Cloudflare Workers, free plan).
//
// GET  /?url=…&id=…&v=…&name=…  install manifest for an IPA served by SayoSign on 127.0.0.1
// GET  /udid                     configuration profile that asks iOS for this iPhone's UDID
// POST /udid/receive             iOS posts the UDID here (Profile Service), we redirect back
// GET  /udid/done?u=…            page that hands the UDID to the SayoSign app
//
// Nothing is stored: the UDID only travels back to the phone in the redirect.

const x = (s) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;" }[c]));
const UDID = /^[0-9A-Fa-f-]{20,50}$/;

function manifest(q) {
  const ipa = q.get("url") || "";
  const id = q.get("id") || "";
  const ver = q.get("v") || "1.0";
  const name = q.get("name") || "App";
  let u;
  try { u = new URL(ipa); } catch { return new Response("bad url", { status: 400 }); }
  if (!["127.0.0.1", "localhost"].includes(u.hostname) || !/^https?:$/.test(u.protocol) || !/^[A-Za-z0-9.\-]+$/.test(id)) {
    return new Response("only local IPA links are allowed", { status: 400 });
  }
  const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>items</key><array><dict>
<key>assets</key><array><dict><key>kind</key><string>software-package</string><key>url</key><string>${x(ipa)}</string></dict></array>
<key>metadata</key><dict>
<key>bundle-identifier</key><string>${x(id)}</string>
<key>bundle-version</key><string>${x(ver)}</string>
<key>kind</key><string>software</string>
<key>title</key><string>${x(name)}</string>
</dict></dict></array></dict></plist>`;
  return new Response(plist, { headers: { "content-type": "application/xml; charset=utf-8", "cache-control": "no-store" } });
}

function udidProfile(origin) {
  const profile = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>PayloadContent</key><dict>
<key>URL</key><string>${x(origin)}/udid/receive</string>
<key>DeviceAttributes</key><array><string>UDID</string><string>PRODUCT</string></array>
</dict>
<key>PayloadOrganization</key><string>SayoSign</string>
<key>PayloadDisplayName</key><string>SayoSign UDID</string>
<key>PayloadDescription</key><string>Sends this iPhone's UDID back to the SayoSign app. Nothing is installed or stored.</string>
<key>PayloadIdentifier</key><string>dev.murk.sayosign.udid</string>
<key>PayloadUUID</key><string>${crypto.randomUUID().toUpperCase()}</string>
<key>PayloadType</key><string>Profile Service</string>
<key>PayloadVersion</key><integer>1</integer>
</dict></plist>`;
  return new Response(profile, {
    headers: { "content-type": "application/x-apple-aspen-config", "content-disposition": 'attachment; filename="SayoSign-UDID.mobileconfig"', "cache-control": "no-store" },
  });
}

async function udidReceive(request, origin) {
  // The body is a signed (PKCS#7) plist; the plist text inside is readable as is.
  const body = new TextDecoder("latin1").decode(await request.arrayBuffer());
  const m = body.match(/<key>UDID<\/key>\s*<string>([^<]+)<\/string>/);
  const p = body.match(/<key>PRODUCT<\/key>\s*<string>([^<]+)<\/string>/);
  if (!m || !UDID.test(m[1])) return new Response("no UDID", { status: 400 });
  const to = `${origin}/udid/done?u=${encodeURIComponent(m[1])}&p=${encodeURIComponent(p ? p[1] : "")}`;
  return new Response(null, { status: 301, headers: { location: to } });
}

function udidDone(q) {
  const u = q.get("u") || "";
  if (!UDID.test(u)) return new Response("bad UDID", { status: 400 });
  const app = `sayosign://udid?value=${encodeURIComponent(u)}`;
  const html = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SayoSign UDID</title><style>body{font:17px -apple-system,sans-serif;margin:0;padding:32px 20px;background:#111;color:#eee;text-align:center}
code{display:block;margin:16px 0;padding:12px;background:#222;border-radius:12px;word-break:break-all;font-size:15px}
a{display:inline-block;margin-top:8px;padding:14px 28px;border-radius:14px;background:#e8506a;color:#fff;text-decoration:none;font-weight:600}</style></head>
<body><h2>Your UDID</h2><code>${x(u)}</code><a href="${x(app)}">Open SayoSign</a>
<script>setTimeout(function(){location.href=${JSON.stringify(app)}},300)</script></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });
}

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const origin = url.origin;
    if (url.pathname === "/udid" && request.method === "GET") return udidProfile(origin);
    if (url.pathname === "/udid/receive" && request.method === "POST") return udidReceive(request, origin);
    if (url.pathname === "/udid/done") return udidDone(url.searchParams);
    return manifest(url.searchParams);
  },
};
