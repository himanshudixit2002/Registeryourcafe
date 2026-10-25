# Professional Firebase Auth emails (verification & password reset)

Auth messages are **sent by Google’s Firebase Auth service**. Most branding is configured in the **Firebase Console**, not in Flutter.

**Path:** [Firebase Console](https://console.firebase.google.com) → your project → **Build** → **Authentication** → **Templates** (tab).

### What you can edit in the console (by template)

Per [Firebase Help — Customize account management emails](https://support.google.com/firebase/answer/7000714):

- **Email address verification** and **Email address change**: you can set **sender name**, **sender domain** (after verification), **reply-to**, **subject**, and **action URL**. The **message body is fixed** — the console shows a tooltip like *“To help prevent spam, the message can’t be edited on this email template.”* That is expected; Firebase does not allow custom HTML here.
- **Password reset**: you can edit **message (HTML)** as well. Paste [`firebase/email_templates/password_reset_email.html`](firebase/email_templates/password_reset_email.html) there.

For every template you edit, also set:

- **Sender name** — e.g. `Register Your Cafe` (matches your brand).
- **Subject** — see suggestions below.

Set **Authentication** → **Settings** → **User actions** → **Public-facing name** to the same brand (this feeds `%APP_NAME%` in subjects and in fixed verification copy).

### If you need custom HTML for verification email

Use the **Admin SDK** to generate the link and send mail with your own template (SendGrid, SES, etc.): [Generating email action links](https://firebase.google.com/docs/auth/admin/email-action-links). The file [`firebase/email_templates/verification_email.html`](firebase/email_templates/verification_email.html) is a **reference layout** for that flow (or for copy ideas), not something you can paste into the verification template in the console.

## Placeholders (official)

| Placeholder | Meaning |
|-------------------|---------|
| `%LINK%`          | Action URL (required for the button). |
| `%EMAIL%`         | Recipient’s email. |
| `%APP_NAME%`      | Public-facing name from Auth settings. |
| `%DISPLAY_NAME%`  | Display name when available. |

Do not remove `%LINK%`; users must click it to verify or reset.

## Spam / “go to inbox normally”

The **default** sender is a Google/Firebase address. Gmail often files those under **Promotions** or **Spam** until users trust them. **Application code cannot force the Primary inbox.**

What actually helps:

1. **Custom sender domain** (strongest): In the template editor, use **Customize domain** / sender domain flow and complete **domain verification** (DNS). Then mail is aligned with your brand and tends to score better. Requires following [Firebase / Google help](https://support.google.com/firebase/answer/7000714) for your plan.
2. **Consistent branding** — professional **subject** + real **Reply-to** (e.g. `support@yourdomain.com`); custom **HTML** only where the console allows it (password reset), or via Admin SDK + your SMTP for verification.
3. **User education** — first login: “If you don’t see the email, check Spam and Promotions.”
4. **Avoid** all-caps subjects, excessive `!!!`, and spammy phrases.

For **fully custom** HTML and your own SMTP (SendGrid, etc.), you’d use the **Admin SDK** to generate links and send mail yourself — see [Generating email action links](https://firebase.google.com/docs/auth/admin/email-action-links). That is a larger backend change.

## Subjects (suggested)

- Verification: `Confirm your email — Register Your Cafe`
- Password reset: `Reset your password — Register Your Cafe`

Adjust to match your legal product name.

## After editing templates

Use **Send test email** in the console if available, then register a real test user and confirm layout in Gmail (desktop + mobile).
