// Settings come from the environment (docker compose passes /srv/babycare/.env). Secrets are never logged.

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing environment variable ${name}`);
  return value;
}

function optional(name: string): string | undefined {
  return process.env[name] || undefined;
}

export interface Config {
  port: number;
  /** Public base URL, e.g. https://158-178-232-52.sslip.io; links in emails and OAuth callbacks start with it. */
  siteURL: string;
  databaseURL: string;
  /** HS256 key for access tokens. */
  jwtSecret: string;
  /** The key the app sends as `apikey`, in place of Supabase's publishable key. */
  publishableKey: string;
  accessTokenSeconds: number;
  /** Redirects the auth endpoints may send users back to, such as babycare://auth-callback. */
  redirectAllowList: string[];
  filesDirectory: string;
  smtp?: { host: string; port: number; user: string; password: string; sender: string; senderName: string };
  apple: { bundleID: string; teamID?: string; keyID?: string; privateKey?: string };
  google?: { clientID: string; clientSecret: string };
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const read = (name: string) => env[name] || undefined;
  void optional;
  const siteURL = (read('SITE_URL') ?? required('SITE_URL')).replace(/\/$/, '');
  const smtpHost = read('SMTP_HOST');
  const googleID = read('GOOGLE_CLIENT_ID');
  return {
    port: Number(read('PORT') ?? 8080),
    siteURL,
    databaseURL: read('DATABASE_URL') ?? required('DATABASE_URL'),
    jwtSecret: read('JWT_SECRET') ?? required('JWT_SECRET'),
    publishableKey: read('PUBLISHABLE_KEY') ?? required('PUBLISHABLE_KEY'),
    accessTokenSeconds: Number(read('ACCESS_TOKEN_SECONDS') ?? 3600),
    redirectAllowList: (read('REDIRECT_ALLOW_LIST') ?? 'babycare://auth-callback').split(',').map(s => s.trim()).filter(Boolean),
    filesDirectory: read('FILES_DIRECTORY') ?? '/srv/files',
    smtp: smtpHost ? {
      host: smtpHost,
      port: Number(read('SMTP_PORT') ?? 587),
      user: read('SMTP_USER') ?? '',
      password: read('SMTP_PASSWORD') ?? '',
      sender: read('SMTP_SENDER') ?? '',
      senderName: read('SMTP_SENDER_NAME') ?? 'Bé Khỏe',
    } : undefined,
    apple: {
      bundleID: read('APPLE_BUNDLE_ID') ?? 'com.vuthanhdo.BabyCare',
      teamID: read('APPLE_TEAM_ID'),
      keyID: read('APPLE_KEY_ID'),
      privateKey: read('APPLE_PRIVATE_KEY')?.replace(/\\n/g, '\n'),
    },
    google: googleID ? { clientID: googleID, clientSecret: read('GOOGLE_CLIENT_SECRET') ?? '' } : undefined,
  };
}
