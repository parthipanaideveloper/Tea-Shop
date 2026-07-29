const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURATION — Fill in your Gmail details below
//
// GMAIL_USER    → your Gmail address (e.g. yourname@gmail.com)
// GMAIL_PASS    → Gmail APP PASSWORD (NOT your login password)
//                 Get it from: myaccount.google.com → Security
//                 → 2-Step Verification → App Passwords → Create
// ADMIN_EMAIL   → email where you want to receive notifications
//                 (can be the same Gmail, or any other email)
// ─────────────────────────────────────────────────────────────────────────────
const GMAIL_USER = "shanerohit264no@gmail.com";
const GMAIL_PASS = "lqvjtekfeinjzona"; // Gmail App Password
const ADMIN_EMAIL = "shanerohit264no@gmail.com"; // admin alert destination

// Create reusable Gmail transporter
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: GMAIL_USER,
    pass: GMAIL_PASS,
  },
});

/**
 * Fires whenever a document is created/updated in activation_requests.
 * Sends a free Gmail email alert to the admin with full device details.
 */
exports.notifyAdminOnActivation = functions
    .region("asia-south1") // Mumbai server — low latency for India
    .firestore.document("activation_requests/{deviceId}")
    .onWrite(async (change, context) => {
      if (!change.after.exists) return null; // ignore deletes

      const data = change.after.data();
      const deviceId = context.params.deviceId;

      const mobile = data.mobile || "Unknown";
      const activationKey = data.activationKey || "N/A";
      const attempts = data.attempts || 1;

      // Indian Standard Time
      const now = new Date();
      const istTime = now.toLocaleString("en-IN", {
        timeZone: "Asia/Kolkata",
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        hour12: true,
      });

      const mailOptions = {
        from: `"DTS POS Alerts" <${GMAIL_USER}>`,
        to: ADMIN_EMAIL,
        subject: `🔔 New Activation Request — ${mobile}`,
        // Plain text version (for phone notifications preview)
        text:
          `NEW STORE ACTIVATION REQUEST\n\n` +
          `Mobile:     ${mobile}\n` +
          `Device ID:  ${deviceId}\n` +
          `Secret Key: ${activationKey}\n` +
          `Attempt:    ${attempts}/3\n` +
          `Time:       ${istTime}\n\n` +
          `Share the Secret Key with the customer to activate their store.`,
        // Rich HTML version
        html: `
          <div style="font-family:Arial,sans-serif;max-width:500px;
                      border:1px solid #e2e8f0;border-radius:12px;
                      padding:24px;background:#f8fafc;">
            <h2 style="color:#0f172a;margin-top:0;">
              🔔 New Store Activation Request
            </h2>
            <table style="width:100%;border-collapse:collapse;">
              <tr style="background:#fff;border-radius:8px;">
                <td style="padding:10px;color:#64748b;width:120px;">📱 Mobile</td>
                <td style="padding:10px;font-weight:bold;color:#0f172a;">
                  ${mobile}
                </td>
              </tr>
              <tr style="background:#f1f5f9;">
                <td style="padding:10px;color:#64748b;">🔑 Device ID</td>
                <td style="padding:10px;font-family:monospace;
                           font-weight:bold;color:#0f172a;letter-spacing:1px;">
                  ${deviceId}
                </td>
              </tr>
              <tr style="background:#fff;">
                <td style="padding:10px;color:#64748b;">🗝️ Secret Key</td>
                <td style="padding:10px;font-family:monospace;font-size:20px;
                           font-weight:bold;color:#16a34a;letter-spacing:3px;">
                  ${activationKey}
                </td>
              </tr>
              <tr style="background:#f1f5f9;">
                <td style="padding:10px;color:#64748b;">🔢 Attempt</td>
                <td style="padding:10px;color:#0f172a;">${attempts} / 3</td>
              </tr>
              <tr style="background:#fff;">
                <td style="padding:10px;color:#64748b;">⏰ Time</td>
                <td style="padding:10px;color:#0f172a;">${istTime}</td>
              </tr>
            </table>
            <div style="margin-top:20px;padding:14px;background:#dcfce7;
                        border-radius:8px;border-left:4px solid #16a34a;">
              <strong>Action Required:</strong> Share the Secret Key above
              with the customer on WhatsApp to complete store activation.
            </div>
          </div>
        `,
      };

      try {
        await transporter.sendMail(mailOptions);
        console.log(`✅ Email alert sent for device ${deviceId} → ${ADMIN_EMAIL}`);
      } catch (error) {
        console.error(`❌ Email failed for ${deviceId}:`, error.message);
      }

      return null;
    });
