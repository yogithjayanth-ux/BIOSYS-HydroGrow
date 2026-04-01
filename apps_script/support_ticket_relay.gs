/**
 * HydroSense: Support Ticket Email Relay (Google Apps Script)
 *
 * Sends support ticket emails without Firebase Cloud Functions (so it works on
 * the Firebase Spark plan).
 *
 * Setup:
 * 1) Go to https://script.google.com and create a new project
 * 2) Paste this file into the editor (e.g. Code.gs)
 * 3) (Optional) Set Script Properties:
 *    - SUPPORT_TO: recipient email (default: lunseargen@gmail.com)
 *    - SUBJECT_PREFIX: email subject prefix (default: [HydroSense Ticket])
 * 4) Deploy -> New deployment -> Web app
 *    - Execute as: Me
 *    - Who has access: Anyone
 * 5) Copy the Web app URL (ends with /exec) and set it in Flutter as
 *    SUPPORT_RELAY_URL via --dart-define.
 */

const DEFAULT_SUPPORT_TO = "lunseargen@gmail.com";
const DEFAULT_SUBJECT_PREFIX = "[HydroSense Ticket]";

// Very simple rate limiting to reduce abuse: N requests per hour per key.
const RATE_LIMIT_PER_HOUR = 15;

function doPost(e) {
  try {
    const data = readRequest_(e);

    const ticketId = normalize_(data.ticketId);
    const contactEmail = normalize_(data.contactEmail);
    const message = normalize_(data.message);
    const userEmail = normalize_(data.userEmail);
    const uid = normalize_(data.uid);

    if (!contactEmail) return json_({ ok: false, error: "Missing contactEmail" });
    if (!message) return json_({ ok: false, error: "Missing message" });

    const rateKey = uid || contactEmail || "unknown";
    if (!checkRateLimit_(rateKey)) {
      return json_({ ok: false, error: "Rate limited" });
    }

    const to = getProp_("SUPPORT_TO") || DEFAULT_SUPPORT_TO;
    const subjectPrefix = getProp_("SUBJECT_PREFIX") || DEFAULT_SUBJECT_PREFIX;
    const subject = ticketId ? `${subjectPrefix} ${ticketId}` : subjectPrefix;

    const bodyLines = [
      ticketId ? `Ticket: ${ticketId}` : null,
      `Contact: ${contactEmail}`,
      userEmail ? `User: ${userEmail}` : null,
      uid ? `UID: ${uid}` : null,
      "",
      message,
    ].filter(Boolean);

    GmailApp.sendEmail(to, subject, bodyLines.join("\n"), {
      replyTo: contactEmail,
      name: "HydroSense Support",
    });

    return json_({ ok: true });
  } catch (err) {
    return json_({ ok: false, error: String(err && err.message ? err.message : err) });
  }
}

function doGet(_) {
  return json_({ ok: true, info: "HydroSense support relay running" });
}

function readRequest_(e) {
  const result = {};

  // JSON body (mobile/desktop/CLI).
  const contents = e && e.postData && e.postData.contents ? String(e.postData.contents) : "";
  if (contents) {
    try {
      const parsed = JSON.parse(contents);
      if (parsed && typeof parsed === "object") Object.assign(result, parsed);
    } catch (_) {}
  }

  // Form fields (web fallback via <form> POST).
  const params = (e && e.parameter) || {};
  for (const k in params) {
    if (Object.prototype.hasOwnProperty.call(params, k) && result[k] == null) {
      result[k] = params[k];
    }
  }

  return result;
}

function normalize_(value) {
  if (value == null) return "";
  return String(value).trim();
}

function getProp_(key) {
  return PropertiesService.getScriptProperties().getProperty(key) || "";
}

function checkRateLimit_(key) {
  const cache = CacheService.getScriptCache();
  const cacheKey = `rl:${key}`;

  const current = Number(cache.get(cacheKey) || "0");
  if (current >= RATE_LIMIT_PER_HOUR) return false;

  cache.put(cacheKey, String(current + 1), 60 * 60); // 1 hour
  return true;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

