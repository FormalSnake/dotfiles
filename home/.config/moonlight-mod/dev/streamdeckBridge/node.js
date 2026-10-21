"use strict";
var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// src/streamdeckBridge/node.ts
var import_node_fs = __toESM(require("node:fs"));
var import_node_net = __toESM(require("node:net"));
var import_node_path = __toESM(require("node:path"));
var SOCKET = import_node_path.default.join(process.env.XDG_RUNTIME_DIR ?? "/tmp", "discord-streamdeck.sock");
var logger = moonlightNode.getLogger("streamdeckBridge");
var clients = /* @__PURE__ */ new Set();
var state = "null";
var server = null;
function listen(onCommand) {
  import_node_fs.default.rmSync(SOCKET, { force: true });
  server = import_node_net.default.createServer((sock) => {
    clients.add(sock);
    sock.setEncoding("utf8");
    sock.write(state + "\n");
    let buf = "";
    sock.on("data", (chunk) => {
      buf += chunk;
      let nl;
      while ((nl = buf.indexOf("\n")) >= 0) {
        const line = buf.slice(0, nl);
        buf = buf.slice(nl + 1);
        if (line)
          onCommand(line);
      }
    });
    sock.on("close", () => clients.delete(sock));
    sock.on("error", () => clients.delete(sock));
  });
  server.on("error", (err) => logger.error("socket", err));
  server.listen(SOCKET);
}
module.exports = {
  start(onCommand) {
    if (server == null)
      listen(onCommand);
  },
  publish(next) {
    if (next === state)
      return;
    state = next;
    for (const sock of clients)
      sock.write(state + "\n");
  }
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vc3JjL3N0cmVhbWRlY2tCcmlkZ2Uvbm9kZS50cyJdLAogICJzb3VyY2VzQ29udGVudCI6IFsiaW1wb3J0IGZzIGZyb20gXCJub2RlOmZzXCI7XG5pbXBvcnQgbmV0IGZyb20gXCJub2RlOm5ldFwiO1xuaW1wb3J0IHBhdGggZnJvbSBcIm5vZGU6cGF0aFwiO1xuXG4vLyBzdHJlYW1kZWNrLWtleXMgKHVzZXJzL2t5YW5kZXN1dHRlci9taXhpbnMvZGV2aWNlcy9zdHJlYW1kZWNrLm5peCkgY29ubmVjdHNcbi8vIGhlcmUuIE5ld2xpbmUtZGVsaW1pdGVkIEpTT04gYm90aCB3YXlzOiB0aGUgbGF0ZXN0IHN0YXRlIGdvZXMgb3V0IG9uIGNvbm5lY3Rcbi8vIGFuZCBvbiBldmVyeSBjaGFuZ2UsIGNvbW1hbmRzIGNvbWUgYmFjayBpbi5cbmNvbnN0IFNPQ0tFVCA9IHBhdGguam9pbihwcm9jZXNzLmVudi5YREdfUlVOVElNRV9ESVIgPz8gXCIvdG1wXCIsIFwiZGlzY29yZC1zdHJlYW1kZWNrLnNvY2tcIik7XG5cbmNvbnN0IGxvZ2dlciA9IG1vb25saWdodE5vZGUuZ2V0TG9nZ2VyKFwic3RyZWFtZGVja0JyaWRnZVwiKTtcbmNvbnN0IGNsaWVudHMgPSBuZXcgU2V0PG5ldC5Tb2NrZXQ+KCk7XG5sZXQgc3RhdGUgPSBcIm51bGxcIjtcbmxldCBzZXJ2ZXI6IG5ldC5TZXJ2ZXIgfCBudWxsID0gbnVsbDtcblxuZnVuY3Rpb24gbGlzdGVuKG9uQ29tbWFuZDogKGxpbmU6IHN0cmluZykgPT4gdm9pZCkge1xuICAvLyBBIGNyYXNoZWQgRGlzY29yZCBsZWF2ZXMgdGhlIHNvY2tldCBmaWxlIGJlaGluZCwgYW5kIGxpc3RlbigpIHJlZnVzZXNcbiAgLy8gYW4gZXhpc3RpbmcgcGF0aC5cbiAgZnMucm1TeW5jKFNPQ0tFVCwgeyBmb3JjZTogdHJ1ZSB9KTtcbiAgc2VydmVyID0gbmV0LmNyZWF0ZVNlcnZlcigoc29jaykgPT4ge1xuICAgIGNsaWVudHMuYWRkKHNvY2spO1xuICAgIHNvY2suc2V0RW5jb2RpbmcoXCJ1dGY4XCIpO1xuICAgIHNvY2sud3JpdGUoc3RhdGUgKyBcIlxcblwiKTtcbiAgICBsZXQgYnVmID0gXCJcIjtcbiAgICBzb2NrLm9uKFwiZGF0YVwiLCAoY2h1bms6IHN0cmluZykgPT4ge1xuICAgICAgYnVmICs9IGNodW5rO1xuICAgICAgbGV0IG5sO1xuICAgICAgd2hpbGUgKChubCA9IGJ1Zi5pbmRleE9mKFwiXFxuXCIpKSA+PSAwKSB7XG4gICAgICAgIGNvbnN0IGxpbmUgPSBidWYuc2xpY2UoMCwgbmwpO1xuICAgICAgICBidWYgPSBidWYuc2xpY2UobmwgKyAxKTtcbiAgICAgICAgaWYgKGxpbmUpIG9uQ29tbWFuZChsaW5lKTtcbiAgICAgIH1cbiAgICB9KTtcbiAgICBzb2NrLm9uKFwiY2xvc2VcIiwgKCkgPT4gY2xpZW50cy5kZWxldGUoc29jaykpO1xuICAgIHNvY2sub24oXCJlcnJvclwiLCAoKSA9PiBjbGllbnRzLmRlbGV0ZShzb2NrKSk7XG4gIH0pO1xuICBzZXJ2ZXIub24oXCJlcnJvclwiLCAoZXJyKSA9PiBsb2dnZXIuZXJyb3IoXCJzb2NrZXRcIiwgZXJyKSk7XG4gIHNlcnZlci5saXN0ZW4oU09DS0VUKTtcbn1cblxubW9kdWxlLmV4cG9ydHMgPSB7XG4gIHN0YXJ0KG9uQ29tbWFuZDogKGxpbmU6IHN0cmluZykgPT4gdm9pZCkge1xuICAgIGlmIChzZXJ2ZXIgPT0gbnVsbCkgbGlzdGVuKG9uQ29tbWFuZCk7XG4gIH0sXG4gIHB1Ymxpc2gobmV4dDogc3RyaW5nKSB7XG4gICAgaWYgKG5leHQgPT09IHN0YXRlKSByZXR1cm47XG4gICAgc3RhdGUgPSBuZXh0O1xuICAgIGZvciAoY29uc3Qgc29jayBvZiBjbGllbnRzKSBzb2NrLndyaXRlKHN0YXRlICsgXCJcXG5cIik7XG4gIH1cbn07XG4iXSwKICAibWFwcGluZ3MiOiAiOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O0FBQUEscUJBQWU7QUFDZixzQkFBZ0I7QUFDaEIsdUJBQWlCO0FBS2pCLElBQU0sU0FBUyxpQkFBQUEsUUFBSyxLQUFLLFFBQVEsSUFBSSxtQkFBbUIsUUFBUSx5QkFBeUI7QUFFekYsSUFBTSxTQUFTLGNBQWMsVUFBVSxrQkFBa0I7QUFDekQsSUFBTSxVQUFVLG9CQUFJLElBQWdCO0FBQ3BDLElBQUksUUFBUTtBQUNaLElBQUksU0FBNEI7QUFFaEMsU0FBUyxPQUFPLFdBQW1DO0FBR2pELGlCQUFBQyxRQUFHLE9BQU8sUUFBUSxFQUFFLE9BQU8sS0FBSyxDQUFDO0FBQ2pDLFdBQVMsZ0JBQUFDLFFBQUksYUFBYSxDQUFDLFNBQVM7QUFDbEMsWUFBUSxJQUFJLElBQUk7QUFDaEIsU0FBSyxZQUFZLE1BQU07QUFDdkIsU0FBSyxNQUFNLFFBQVEsSUFBSTtBQUN2QixRQUFJLE1BQU07QUFDVixTQUFLLEdBQUcsUUFBUSxDQUFDLFVBQWtCO0FBQ2pDLGFBQU87QUFDUCxVQUFJO0FBQ0osY0FBUSxLQUFLLElBQUksUUFBUSxJQUFJLE1BQU0sR0FBRztBQUNwQyxjQUFNLE9BQU8sSUFBSSxNQUFNLEdBQUcsRUFBRTtBQUM1QixjQUFNLElBQUksTUFBTSxLQUFLLENBQUM7QUFDdEIsWUFBSTtBQUFNLG9CQUFVLElBQUk7QUFBQSxNQUMxQjtBQUFBLElBQ0YsQ0FBQztBQUNELFNBQUssR0FBRyxTQUFTLE1BQU0sUUFBUSxPQUFPLElBQUksQ0FBQztBQUMzQyxTQUFLLEdBQUcsU0FBUyxNQUFNLFFBQVEsT0FBTyxJQUFJLENBQUM7QUFBQSxFQUM3QyxDQUFDO0FBQ0QsU0FBTyxHQUFHLFNBQVMsQ0FBQyxRQUFRLE9BQU8sTUFBTSxVQUFVLEdBQUcsQ0FBQztBQUN2RCxTQUFPLE9BQU8sTUFBTTtBQUN0QjtBQUVBLE9BQU8sVUFBVTtBQUFBLEVBQ2YsTUFBTSxXQUFtQztBQUN2QyxRQUFJLFVBQVU7QUFBTSxhQUFPLFNBQVM7QUFBQSxFQUN0QztBQUFBLEVBQ0EsUUFBUSxNQUFjO0FBQ3BCLFFBQUksU0FBUztBQUFPO0FBQ3BCLFlBQVE7QUFDUixlQUFXLFFBQVE7QUFBUyxXQUFLLE1BQU0sUUFBUSxJQUFJO0FBQUEsRUFDckQ7QUFDRjsiLAogICJuYW1lcyI6IFsicGF0aCIsICJmcyIsICJuZXQiXQp9Cg==
