const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

async function renderHtmlToPng(htmlPath, pngPath, width, height) {
  const chrome = spawn('google-chrome', [
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--disable-extensions',
    '--disable-sync',
    '--disable-background-networking',
    `--window-size=${width},${height}`,
    '--remote-debugging-port=9225',
    '--user-data-dir=/tmp/node-chrome-render',
    'about:blank'
  ]);

  try {
    await new Promise(r => setTimeout(r, 1200));

    const listRes = await fetch('http://127.0.0.1:9225/json/list');
    const pages = await listRes.json();
    const wsUrl = pages[0].webSocketDebuggerUrl;

    const ws = new WebSocket(wsUrl);
    await new Promise((resolve) => ws.onopen = resolve);

    let msgId = 1;
    function send(method, params = {}) {
      return new Promise((resolve, reject) => {
        const id = msgId++;
        const timer = setTimeout(() => reject(new Error(`Timeout on ${method}`)), 10000);
        const handler = (event) => {
          const msg = JSON.parse(event.data);
          if (msg.id === id) {
            clearTimeout(timer);
            ws.removeEventListener('message', handler);
            resolve(msg.result);
          }
        };
        ws.addEventListener('message', handler);
        ws.send(JSON.stringify({ id, method, params }));
      });
    }

    await send('Page.enable');
    await send('Emulation.setDeviceMetricsOverride', {
      width: width,
      height: height,
      deviceScaleFactor: 2, // 2x high-DPI crystal-clear output!
      mobile: false
    });

    const fileUrl = 'file://' + path.resolve(htmlPath);
    await send('Page.navigate', { url: fileUrl });
    await new Promise(r => setTimeout(r, 1000));

    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      fromSurface: true
    });

    fs.writeFileSync(pngPath, Buffer.from(shot.data, 'base64'));
    console.log(`Rendered ${pngPath} (${fs.statSync(pngPath).size} bytes)`);

    ws.close();
  } finally {
    chrome.kill();
  }
}

async function main() {
  console.log('Rendering Context Diagram...');
  await renderHtmlToPng(
    '/workspace/docs/diagrams/context_diagram.html',
    '/workspace/docs/diagrams/context_diagram.png',
    1460,
    1040
  );

  console.log('Rendering Top-Level Diagram...');
  await renderHtmlToPng(
    '/workspace/docs/diagrams/toplevel_diagram.html',
    '/workspace/docs/diagrams/toplevel_diagram.png',
    1760,
    1280
  );

  console.log('All diagrams generated successfully!');
}

main().catch(err => {
  console.error('Error generating diagrams:', err);
  process.exit(1);
});
