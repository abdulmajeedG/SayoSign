export default {
  async fetch(request) {
    const q = new URL(request.url).searchParams;
    const ipa = q.get("url") || "";
    const id = q.get("id") || "";
    const ver = q.get("v") || "1.0";
    const name = q.get("name") || "App";

    let u;
    try { u = new URL(ipa); } catch { return new Response("bad url", { status: 400 }); }
    if (!["127.0.0.1", "localhost"].includes(u.hostname) || !/^https?:$/.test(u.protocol) || !/^[A-Za-z0-9.\-]+$/.test(id)) {
      return new Response("only local IPA links are allowed", { status: 400 });
    }

    const x = (s) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;" }[c]));
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
  },
};
