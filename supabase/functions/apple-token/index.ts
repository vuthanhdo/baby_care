// apple-token: keeps the Sign in with Apple refresh token so the app can revoke it when the account is
// deleted (App Store Review Guideline 5.1.1(v)).
//   POST {"action":"link","code":"<authorizationCode>"}  right after a native Apple sign-in (code expires in 5 min)
//   POST {"action":"revoke"}                              right before babycare_delete_account
//   POST {"action":"diag"}                                reports which secrets are present and whether the key loads
// Requires secrets APPLE_TEAM_ID, APPLE_CLIENT_ID (bundle id), APPLE_KEY_ID, APPLE_PRIVATE_KEY (.p8 contents).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const APPLE = "https://appleid.apple.com";
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

async function clientSecret(): Promise<string> {
  const teamID = Deno.env.get("APPLE_TEAM_ID");
  const clientID = Deno.env.get("APPLE_CLIENT_ID");
  const keyID = Deno.env.get("APPLE_KEY_ID");
  const pem = Deno.env.get("APPLE_PRIVATE_KEY");
  if (!teamID || !clientID || !keyID || !pem) throw new Error("Apple secrets are not configured");
  const key = await importPKCS8(pem.replace(/\\n/g, "\n"), "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyID })
    .setIssuer(teamID).setSubject(clientID).setAudience(APPLE)
    .setIssuedAt().setExpirationTime("1h")
    .sign(key);
}

async function appleForm(path: string, params: Record<string, string>): Promise<Response> {
  const body = new URLSearchParams({
    client_id: Deno.env.get("APPLE_CLIENT_ID") ?? "",
    client_secret: await clientSecret(),
    ...params,
  });
  return await fetch(`${APPLE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
}

function subject(idToken: string): string | null {
  try {
    const payload = idToken.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(payload)).sub ?? null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "POST only" });
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: { user }, error } = await supabase.auth.getUser(jwt);
  if (error || !user) return json(401, { error: "Authentication required" });

  let payload: { action?: string; code?: string } = {};
  try {
    payload = await req.json();
  } catch {
    // Empty body: fall through to the action check.
  }

  try {
    if (payload.action === "diag") {
      const present = {
        APPLE_TEAM_ID: !!Deno.env.get("APPLE_TEAM_ID"),
        APPLE_CLIENT_ID: !!Deno.env.get("APPLE_CLIENT_ID"),
        APPLE_KEY_ID: !!Deno.env.get("APPLE_KEY_ID"),
        APPLE_PRIVATE_KEY: !!Deno.env.get("APPLE_PRIVATE_KEY"),
      };
      const pem = Deno.env.get("APPLE_PRIVATE_KEY") ?? "";
      let secret = "ok";
      try {
        await clientSecret();
      } catch (e) {
        secret = e instanceof Error ? e.message : String(e);
      }
      return json(200, { present, pemLines: pem.split("\n").length, pemStartsWithHeader: pem.startsWith("-----BEGIN"), clientSecret: secret });
    }
    if (payload.action === "link") {
      if (!payload.code) return json(400, { error: "code required" });
      const res = await appleForm("/auth/token", { code: payload.code, grant_type: "authorization_code" });
      const token = await res.json();
      if (!res.ok || !token.refresh_token) {
        console.error("apple-token link: exchange failed", res.status, JSON.stringify(token).slice(0, 300));
        return json(502, { error: "Apple token exchange failed", detail: token.error ?? res.status });
      }
      // The code must belong to the signed-in user's Apple identity, never to someone else's.
      const appleID = user.identities?.find((i) => i.provider === "apple")?.id;
      if (!appleID || subject(token.id_token ?? "") !== appleID) {
        return json(403, { error: "Apple identity does not match this account" });
      }
      const { error: dbError } = await supabase.from("apple_tokens").upsert({
        user_id: user.id,
        refresh_token: token.refresh_token,
        updated_at: new Date().toISOString(),
      });
      if (dbError) {
        console.error("apple-token link: upsert failed", dbError.message);
        return json(500, { error: dbError.message });
      }
      return json(200, { linked: true });
    }
    if (payload.action === "revoke") {
      const { data: row } = await supabase.from("apple_tokens").select("refresh_token").eq("user_id", user.id).maybeSingle();
      if (!row) return json(200, { revoked: false, reason: "no apple token for this user" });
      const res = await appleForm("/auth/revoke", { token: row.refresh_token, token_type_hint: "refresh_token" });
      if (!res.ok) return json(502, { revoked: false, error: `Apple revoke failed (${res.status})` });
      await supabase.from("apple_tokens").delete().eq("user_id", user.id);
      return json(200, { revoked: true });
    }
    return json(400, { error: "action must be link or revoke" });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("apple-token", payload.action, "failed:", message);
    return json(500, { error: message });
  }
});
