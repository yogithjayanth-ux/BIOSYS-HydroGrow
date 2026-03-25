#!/usr/bin/env node
/**
 * Firebase RTDB "device" simulator (ESP32-like).
 *
 * - Creates (or reuses) an anonymous Firebase Auth identity
 * - Writes `moisture` + `updatedAt` to:
 *     /devices/<deviceUid>
 * - Appends history points to:
 *     /devices/<deviceUid>/readings/<pushId>  { moisture, ts }
 *
 * This matches the app's expected paths + `archive/database.rules.json`.
 *
 * Usage (from repo root):
 *   cd archive
 *   node tools/rtdb_device_sim.js --once
 *   node tools/rtdb_device_sim.js --interval 5 --min 20 --max 80
 *
 * It stores the device identity at `tools/device_identity.json` so the same
 * System ID is reused across runs.
 */

const fs = require("node:fs");
const path = require("node:path");

const DEFAULT_API_KEY = "AIzaSyCOkkpK-cggYsfc9xm3orWoCv44JQGDgM0";
const DEFAULT_DB_URL = "https://biosense-3bd53-default-rtdb.firebaseio.com";

function parseArgs(argv) {
  const args = {
    apiKey: process.env.FIREBASE_API_KEY || DEFAULT_API_KEY,
    dbUrl: process.env.FIREBASE_DATABASE_URL || DEFAULT_DB_URL,
    intervalSec: 5,
    min: 20,
    max: 80,
    once: false,
    tokenFile: path.join(__dirname, "device_identity.json"),
  };

  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) throw new Error(`Missing value for ${a}`);
      i += 1;
      return argv[i];
    };

    if (a === "--api-key") args.apiKey = next();
    else if (a === "--db-url") args.dbUrl = next();
    else if (a === "--interval") args.intervalSec = Number(next());
    else if (a === "--min") args.min = Number(next());
    else if (a === "--max") args.max = Number(next());
    else if (a === "--once") args.once = true;
    else if (a === "--token-file") args.tokenFile = next();
    else if (a === "-h" || a === "--help") {
      console.log(
        [
          "Usage:",
          "  node tools/rtdb_device_sim.js [--once] [--interval 5] [--min 20] [--max 80]",
          "",
          "Options:",
          "  --api-key <key>        Firebase Web API key (or env FIREBASE_API_KEY)",
          "  --db-url <url>         RTDB URL (or env FIREBASE_DATABASE_URL)",
          "  --interval <seconds>   Write interval (default 5)",
          "  --min <n>              Min moisture (default 20)",
          "  --max <n>              Max moisture (default 80)",
          "  --once                 Write once then exit",
          "  --token-file <path>    Where to store the device identity",
        ].join("\n"),
      );
      process.exit(0);
    }
  }

  if (!Number.isFinite(args.intervalSec) || args.intervalSec <= 0) {
    throw new Error("--interval must be a positive number");
  }
  if (!Number.isFinite(args.min) || !Number.isFinite(args.max) || args.min > args.max) {
    throw new Error("--min/--max must be numbers and min <= max");
  }
  return args;
}

async function postJson(url, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}: ${text}`);
  return text ? JSON.parse(text) : null;
}

async function postForm(url, form) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(form).toString(),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}: ${text}`);
  return text ? JSON.parse(text) : null;
}

async function signUpAnonymously(apiKey) {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${encodeURIComponent(
    apiKey,
  )}`;
  const json = await postJson(url, { returnSecureToken: true });
  return {
    uid: json.localId,
    idToken: json.idToken,
    refreshToken: json.refreshToken,
  };
}

async function refreshIdToken(apiKey, refreshToken) {
  const url = `https://securetoken.googleapis.com/v1/token?key=${encodeURIComponent(apiKey)}`;
  const json = await postForm(url, {
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  });
  return {
    uid: json.user_id,
    idToken: json.id_token,
    refreshToken: json.refresh_token || refreshToken,
  };
}

function loadIdentity(tokenFile) {
  try {
    const raw = fs.readFileSync(tokenFile, "utf8");
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return null;
    if (typeof parsed.refreshToken !== "string" || parsed.refreshToken.trim() === "") return null;
    if (typeof parsed.uid !== "string" || parsed.uid.trim() === "") return null;
    return { uid: parsed.uid, refreshToken: parsed.refreshToken };
  } catch (_) {
    return null;
  }
}

function saveIdentity(tokenFile, identity) {
  fs.writeFileSync(
    tokenFile,
    JSON.stringify({ uid: identity.uid, refreshToken: identity.refreshToken }, null, 2) + "\n",
    "utf8",
  );
}

function normalizeDbUrl(dbUrl) {
  return dbUrl.replace(/\/+$/, "");
}

async function rtdbPatch(dbUrl, pathPart, idToken, data) {
  const url =
    `${normalizeDbUrl(dbUrl)}/` +
    `${pathPart.replace(/^\/+/, "")}.json` +
    `?auth=${encodeURIComponent(idToken)}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(data),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}: ${text}`);
  return text ? JSON.parse(text) : null;
}

async function rtdbPost(dbUrl, pathPart, idToken, data) {
  const url =
    `${normalizeDbUrl(dbUrl)}/` +
    `${pathPart.replace(/^\/+/, "")}.json` +
    `?auth=${encodeURIComponent(idToken)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(data),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}: ${text}`);
  return text ? JSON.parse(text) : null;
}

function randInt(min, max) {
  const lo = Math.ceil(min);
  const hi = Math.floor(max);
  return Math.floor(Math.random() * (hi - lo + 1)) + lo;
}

async function ensureDeviceIdentity(apiKey, tokenFile) {
  const existing = loadIdentity(tokenFile);
  if (existing) {
    const refreshed = await refreshIdToken(apiKey, existing.refreshToken);
    saveIdentity(tokenFile, refreshed);
    return refreshed;
  }
  const created = await signUpAnonymously(apiKey);
  saveIdentity(tokenFile, created);
  return created;
}

async function writeOnce(args, device) {
  const moisture = randInt(args.min, args.max);
  const ts = Date.now();

  await rtdbPost(args.dbUrl, `/devices/${device.uid}/readings`, device.idToken, { moisture, ts });
  await rtdbPatch(args.dbUrl, `/devices/${device.uid}`, device.idToken, { moisture, updatedAt: ts });

  console.log(`Wrote: moisture=${moisture} ts=${ts}`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  console.log(`RTDB URL: ${args.dbUrl}`);
  console.log(`Identity file: ${args.tokenFile}`);

  let device;
  try {
    device = await ensureDeviceIdentity(args.apiKey, args.tokenFile);
  } catch (e) {
    console.error(String(e));
    console.error(
      "If this fails with OPERATION_NOT_ALLOWED, enable Anonymous auth in Firebase Console → Authentication → Sign-in method.",
    );
    process.exit(1);
  }

  console.log(`\nSystem ID (device UID): ${device.uid}`);
  console.log("Add this in the app: Systems → + → System ID = the UID above\n");

  const tick = async () => {
    try {
      await writeOnce(args, device);
    } catch (e) {
      // If the ID token expired (or was revoked), refresh and retry once.
      const msg = String(e);
      if (msg.includes("401") || msg.toLowerCase().includes("auth")) {
        device = await ensureDeviceIdentity(args.apiKey, args.tokenFile);
        await writeOnce(args, device);
        return;
      }
      throw e;
    }
  };

  await tick();
  if (args.once) return;

  const ms = Math.round(args.intervalSec * 1000);
  setInterval(() => {
    tick().catch((e) => console.error(String(e)));
  }, ms);
}

main().catch((e) => {
  console.error(String(e));
  process.exit(1);
});
