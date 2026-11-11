import http from "node:http";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";

const publicPort = 8933;
const gatewayPort = 8934;
const probeTimeoutMs = 2_000;
const supervisorStatusFile =
  process.env.CHROME_SUPERVISOR_STATUS_FILE ??
  "/chrome-config/.chromium-supervisor-status.json";
let shuttingDown = false;

const gateway = spawn("supergateway", process.argv.slice(2), {
  stdio: "inherit",
  env: process.env,
});

function probe(port, path, validate = () => true) {
  return new Promise((resolve) => {
    const request = http.get(
      { host: "127.0.0.1", port, path, timeout: probeTimeoutMs },
      (response) => {
        let body = "";
        response.setEncoding("utf8");
        response.on("data", (chunk) => {
          body += chunk;
        });
        response.on("end", () => {
          resolve(response.statusCode === 200 && validate(body));
        });
      },
    );
    request.on("timeout", () => request.destroy());
    request.on("error", () => resolve(false));
  });
}

async function readSupervisorStatus() {
  try {
    const status = JSON.parse(await readFile(supervisorStatusFile, "utf8"));
    return {
      state: status.state,
      restart_attempts: status.restart_attempts,
      max_restart_attempts: status.max_restart_attempts,
      stable_run_seconds: status.stable_run_seconds,
      last_exit_code: status.last_exit_code,
      last_run_seconds: status.last_run_seconds,
      updated_at: status.updated_at,
    };
  } catch {
    return { state: "unknown" };
  }
}

async function healthStatus() {
  const [gatewayHealthy, chromeHealthy] = await Promise.all([
    probe(gatewayPort, "/healthz"),
    probe(9222, "/json/version", (body) => {
      try {
        return Boolean(JSON.parse(body).webSocketDebuggerUrl);
      } catch {
        return false;
      }
    }),
  ]);
  const supervisor = await readSupervisorStatus();
  let error = null;
  if (!gatewayHealthy) {
    error = "MCP gateway is unavailable";
  } else if (supervisor.state === "failed") {
    error = `Chromium exited after ${supervisor.max_restart_attempts} automatic restart attempts; recovery is latched until chrome-stealth is restarted`;
  } else if (supervisor.state === "restarting") {
    error = `Chromium exited with code ${supervisor.last_exit_code}; automatic restart attempt ${supervisor.restart_attempts} of ${supervisor.max_restart_attempts} is pending`;
  } else if (!chromeHealthy) {
    error = "Chromium CDP endpoint is unavailable";
  }
  return {
    status: gatewayHealthy && chromeHealthy ? "healthy" : "unhealthy",
    error,
    gateway: gatewayHealthy ? "available" : "unavailable",
    chrome_cdp: chromeHealthy ? "available" : "unavailable",
    supervisor,
  };
}

const server = http.createServer(async (request, response) => {
  if (request.url === "/healthz") {
    const health = await healthStatus();
    response.writeHead(health.status === "healthy" ? 200 : 503, {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    });
    response.end(`${JSON.stringify(health)}\n`);
    return;
  }

  const headers = { ...request.headers, host: `127.0.0.1:${gatewayPort}` };
  const upstream = http.request(
    {
      host: "127.0.0.1",
      port: gatewayPort,
      method: request.method,
      path: request.url,
      headers,
    },
    (upstreamResponse) => {
      response.writeHead(
        upstreamResponse.statusCode ?? 502,
        upstreamResponse.headers,
      );
      upstreamResponse.pipe(response);
    },
  );

  upstream.on("error", () => {
    if (!response.headersSent) {
      response.writeHead(502, { "content-type": "text/plain; charset=utf-8" });
    }
    response.end("gateway unavailable");
  });
  request.on("aborted", () => upstream.destroy());
  request.pipe(upstream);
});

server.listen(publicPort, "0.0.0.0");

function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  server.close();
  gateway.kill(signal);
}

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => shutdown(signal));
}

gateway.on("exit", (code, signal) => {
  if (!shuttingDown) {
    console.error(
      `supergateway exited unexpectedly (code=${code}, signal=${signal})`,
    );
    server.close(() => process.exit(code ?? 1));
  }
});
