/* eslint-disable */
const admin = require("firebase-admin");
const functions = require("firebase-functions");
const nodemailer = require("nodemailer");

admin.initializeApp();

const DEFAULT_SUPPORT_TO = "lunseargen@gmail.com";

function readList(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value.map(String).map((s) => s.trim()).filter(Boolean);
  return String(value)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function getEmailConfig() {
  const smtp = (functions.config() && functions.config().smtp) || {};
  const support = (functions.config() && functions.config().support) || {};

  const host = String(smtp.host || "").trim();
  const port = Number(smtp.port || 465);
  const secure = String(smtp.secure || "true").toLowerCase() !== "false";
  const user = String(smtp.user || "").trim();
  const pass = String(smtp.pass || "").trim();
  const from = String(smtp.from || user).trim();

  const to = readList(support.to);
  const subjectPrefix = String(support.subject_prefix || "[HydroSense Ticket]").trim();

  return {
    smtp: { host, port, secure, user, pass, from },
    support: { to: to.length > 0 ? to : [DEFAULT_SUPPORT_TO], subjectPrefix },
  };
}

function createTransport(smtp) {
  return nodemailer.createTransport({
    host: smtp.host,
    port: smtp.port,
    secure: smtp.secure,
    auth: {
      user: smtp.user,
      pass: smtp.pass,
    },
  });
}

exports.emailSupportTicket = functions.firestore
  .document("supportTickets/{ticketId}")
  .onCreate(async (snap, context) => {
    const ticketId = context.params.ticketId;
    const data = snap.data() || {};

    const { smtp, support } = getEmailConfig();
    if (!smtp.host || !smtp.user || !smtp.pass || !smtp.from) {
      functions.logger.error(
        "Missing SMTP config. Set via firebase functions:config:set smtp.host=... smtp.user=... smtp.pass=... [smtp.from=...]",
      );
      return;
    }
    if (!support.to || support.to.length === 0) {
      functions.logger.error(
        `Missing support recipient(s). Set via firebase functions:config:set support.to="${DEFAULT_SUPPORT_TO}"`,
      );
      return;
    }

    // Best-effort idempotency: if the doc was updated by a previous run, skip.
    try {
      const fresh = await snap.ref.get();
      if (fresh.exists && fresh.get("emailSentAt")) return;
    } catch (_) {}

    const contactEmail = String(data.contactEmail || "").trim();
    const message = String(data.message || "").trim();
    const userEmail = String(data.userEmail || "").trim();
    const uid = String(data.uid || "").trim();

    const subject = `${support.subjectPrefix} ${ticketId}`;
    const bodyLines = [
      `Ticket: ${ticketId}`,
      contactEmail ? `Contact: ${contactEmail}` : null,
      userEmail ? `User: ${userEmail}` : null,
      uid ? `UID: ${uid}` : null,
      "",
      message || "(no message)",
    ].filter((l) => l !== null);

    const transport = createTransport(smtp);
    try {
      await transport.sendMail({
        from: smtp.from,
        to: support.to,
        subject,
        text: bodyLines.join("\n"),
        replyTo: contactEmail || undefined,
      });
      await snap.ref.update({
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        emailError: admin.firestore.FieldValue.delete(),
      });
    } catch (e) {
      functions.logger.error("Ticket email send failed", e);
      await snap.ref.update({
        emailError: String(e && e.message ? e.message : e),
      });
    }
  });
