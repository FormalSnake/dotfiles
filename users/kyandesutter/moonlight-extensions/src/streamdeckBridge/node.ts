import fs from "node:fs";
import net from "node:net";
import path from "node:path";

// streamdeck-keys (users/kyandesutter/mixins/devices/streamdeck.nix) connects
// here. Newline-delimited JSON both ways: the latest state goes out on connect
// and on every change, commands come back in.
const SOCKET = path.join(process.env.XDG_RUNTIME_DIR ?? "/tmp", "discord-streamdeck.sock");

const logger = moonlightNode.getLogger("streamdeckBridge");
const clients = new Set<net.Socket>();
let state = "null";
let server: net.Server | null = null;

function listen(onCommand: (line: string) => void) {
  // A crashed Discord leaves the socket file behind, and listen() refuses
  // an existing path.
  fs.rmSync(SOCKET, { force: true });
  server = net.createServer((sock) => {
    clients.add(sock);
    sock.setEncoding("utf8");
    sock.write(state + "\n");
    let buf = "";
    sock.on("data", (chunk: string) => {
      buf += chunk;
      let nl;
      while ((nl = buf.indexOf("\n")) >= 0) {
        const line = buf.slice(0, nl);
        buf = buf.slice(nl + 1);
        if (line) onCommand(line);
      }
    });
    sock.on("close", () => clients.delete(sock));
    sock.on("error", () => clients.delete(sock));
  });
  server.on("error", (err) => logger.error("socket", err));
  server.listen(SOCKET);
}

module.exports = {
  start(onCommand: (line: string) => void) {
    if (server == null) listen(onCommand);
  },
  publish(next: string) {
    if (next === state) return;
    state = next;
    for (const sock of clients) sock.write(state + "\n");
  }
};
