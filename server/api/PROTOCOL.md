# BabyCare ↔ Supabase wire protocol, as used through supabase-swift 2.55.1

The new backend has to speak this protocol so that the app only changes `CloudConfiguration.url` and
`CloudConfiguration.publishableKey`. Every fact below comes from reading the source code. A few were also
checked by compiling a small Swift program (marked **[verified empirically]**). Nothing here comes from
Supabase documentation unless it says "reference only".

## 0. Sources and citation prefixes

| Prefix | Path |
|---|---|
| `SDK:` | `/Users/vuthanhdo/Library/Developer/Xcode/DerivedData/BabyCare-bmbmtrgipdkslhbrpqvzsjjyslrk/SourcePackages/checkouts/supabase-swift/Sources/` (git HEAD `21d3aaf21ee98f41611f9f75070489fc8b23d882`, tag `v2.55.1`, matching `BabyCare.xcodeproj/.../Package.resolved:9-10`) |
| `APP:` | `/Users/vuthanhdo/Projects/BabyCare/BabyCare/BabyCare/` |
| `SB:` | `/Users/vuthanhdo/Projects/BabyCare/BabyCare/supabase/` |

The briefed path `/private/tmp/claude-501/bc-archive/SourcePackages/checkouts/supabase-swift/Sources` contains
**no files** (empty directories, broken `.git`). I used the DerivedData checkout above instead. It is the same
version (2.55.1) and the same revision as `Package.resolved`. `Sources/HTTPRuntime` is linked only by
`HTTPRuntimeTestHelpers`, so no production module (Auth/PostgREST/Storage/Functions/Supabase) runs through it.
All networking goes through `SDK:Helpers/HTTP/*`.

---

## 1. What really matters (summary of the hard requirements)

1. **Auth flow is PKCE.** The app never sets `flowType` (`APP:Data/Cloud/SupabaseRemote.swift:8-12`), and the
   default is `.pkce` (`SDK:Auth/Defaults.swift:32`, `SDK:Supabase/Types.swift:89`). Every email link and every OAuth
   callback must return to `babycare://auth-callback?code=<auth_code>`. A fragment containing `access_token=...` is
   **rejected** in PKCE mode (`SDK:Auth/AuthClient.swift:971-975`).
2. **`.passwordRecovery` is never emitted in PKCE mode.** Only the implicit branch looks at `type=recovery`
   (`SDK:Auth/AuthClient.swift:1021-1023`). The PKCE branch only exchanges the code and emits `.signedIn`
   (`:1028-1045`, `:761-762`). So `needsNewPassword` (`APP:ViewModels/SessionViewModel.swift:75`) **cannot become true
   today**, and the backend cannot change that while the app stays on PKCE. See §3.9.
3. **Timestamps must be UTC.** The SDK's date parser ignores the UTC offset: `+07:00` is read as if it were `Z`. It
   also rejects a space separator **[verified empirically]**. See §2.5.
4. **GoTrue errors must have a string `code`, or no `code`.** A numeric `code` makes the whole error unreadable.
   To have `code` read as an error code, the response also needs the header `X-Supabase-Api-Version: 2024-01-01`.
   Otherwise the SDK uses `error_code` instead. A failed refresh must use one of these codes, or the user is never
   signed out: `refresh_token_not_found`, `refresh_token_already_used`, `session_not_found`, `session_expired`.
   See §3.2.
5. **PostgREST errors must be JSON `{code, message, details, hint}`** with string `code`/`message`. The app
   branches on exact SQLSTATE plus message pairs (§4.6). An error body that is not JSON becomes `HTTPError`, which
   the app does **not** treat as offline.
6. **Storage errors must be JSON `{statusCode: "<string>", error, message}`.** The app compares `statusCode` as a
   *string* (`"404"`, `"409"`, `"401"`, `"403"`, `"5xx"`), not the HTTP status. Upload success must return
   `{"Key": ..., "Id": ...}` (capitalised).
7. **UUIDs leave the device in UPPERCASE** in RPC bodies and `eq.` filters (Swift `UUID.uuidString`)
   **[verified empirically]**. Storage object paths are lowercased by the app. Optional nil fields are **omitted**
   from RPC bodies, not sent as `null`.
8. **Unauthenticated requests carry `Authorization: Bearer <publishable key>`**, which is not a JWT
   (`SDK:Supabase/SupabaseClient.swift:242-251`). The backend must treat a bearer value equal to the apikey as the
   anon role.

---

## 2. Client construction, transport and encoding

### 2.1 Clients the app creates

* **Main client** (one per process, `SessionViewModel.shared`): `CloudConfiguration.makeClient()`
  (`APP:Data/Cloud/SupabaseRemote.swift:8-12`):
  `SupabaseClient(supabaseURL: url, supabaseKey: publishableKey, options: .init(auth: .init(storage: KeychainLocalStorage(service: "com.vuthanhdo.BabyCare.auth"), storageKey: "babycare.session", emitLocalSessionAsInitialSession: true)))`.
  Everything not passed keeps its default: `flowType = .pkce`, `autoRefreshToken = true`
  (`SDK:Auth/Defaults.swift:32,35`), `redirectToURL = nil`, `db.schema = nil`, `global.session = .shared`,
  `functions.region = nil`, `storage.useNewHostname = false` (`SDK:Supabase/Types.swift:37-45,85-105,119-127,139-162`).
* **Per-family data client** `SupabaseRemote.init` (`APP:Data/Cloud/SupabaseRemote.swift:187-201`): a second
  `SupabaseClient` with `auth: .init(autoRefreshToken: false, accessToken: {...})` and an ephemeral `URLSession`
  (`timeoutIntervalForRequest = 20`). Its `accessToken` closure returns `authClient.auth.session.accessToken` from the
  **main** client, and only when `session.user.id == userID`. Because `accessToken != nil`, this client does not
  listen for auth events (`SDK:Supabase/SupabaseClient.swift:285-287`). Its own AuthClient makes no requests.
  Refreshes therefore always happen in the main client.
* Base URLs: `<url>/auth/v1`, `<url>/rest/v1`, `<url>/storage/v1`, `<url>/functions/v1`. They are built with
  `appendingPathComponent` (`SDK:Supabase/SupabaseClient.swift:238-240,260`), so a base URL with a path prefix keeps
  the prefix. The URL must have a host (`:254-256`, `preconditionFailure` otherwise).

### 2.2 Headers common to every sub-client

`_headers = defaultHeaders ∪ {"Authorization": "Bearer <supabaseKey>", "Apikey": <supabaseKey>} ∪ global.headers`
(`SDK:Supabase/SupabaseClient.swift:242-251`).

* `X-Client-Info: supabase-swift/2.55.1; platform=iOS; platform-version=<x.y.z>; runtime=swift; runtime-version=<6.x>`
  (`SDK:Supabase/Constants.swift:10-28`, `SDK:Helpers/Version.swift:4`). Each sub-client's own default
  X-Client-Info (`auth-swift/…`, `postgrest-swift/…`, `storage-swift/…`, `functions-swift/…`) is used only when the key
  is absent. Here it is always present, so every module sends `supabase-swift/...`
  (`SDK:Auth/AuthClientConfiguration.swift:172`, `SDK:PostgREST/PostgrestClient.swift:194`,
  `SDK:Storage/StorageApi.swift:47-49`, `SDK:Functions/FunctionsClient.swift:147-149`).
* The header is spelled `Apikey`. Read it case-insensitively (HTTP/2 lower-cases it anyway).
* Functions only: when the key is new-format (`sb_publishable_` / `sb_secret_`), the default `Authorization` is
  dropped (`SDK:Supabase/SupabaseClient.swift:152-155`, `SDK:Helpers/APIKeyFormat.swift:17-23`). If the new
  backend issues a key that starts with `sb_` but has another subtype, the SDK raises a runtime warning
  (`APIKeyFormat.swift:30-53`). Keep the `sb_publishable_` prefix, or use a key that does not start with `sb_`.

### 2.3 How `Authorization` is decided per request

* **PostgREST, Storage, Functions** go through `fetchWithAuth`/`adaptRequest`
  (`SDK:Supabase/SupabaseClient.swift:430-472`). Before each request: `token = try? await accessToken()`.
  * Main client: `auth.session.accessToken`. This may trigger a refresh first (§3.8). It throws `sessionMissing`
    when signed out.
  * SupabaseRemote: the closure above. It throws `CloudError.signedOut` when the lease is invalid.
  * If a token was obtained: `Authorization: Bearer <access_token>`. **If it threw: the header keeps the default
    `Bearer <publishable key>`** (Functions: no Authorization header, unless `setAuth` already set one).
* Functions also gets `setAuth(token)` from auth events `.initialSession/.signedIn/.tokenRefreshed`, and the key on
  `.signedOut` (via `functionsBearerToken`, which turns into *no header* for new-format keys)
  (`SDK:Supabase/SupabaseClient.swift:497-521`, `SDK:Helpers/APIKeyFormat.swift:61-63`). `adaptRequest` overrides it
  anyway whenever a session exists.
* **Auth (GoTrue)** does *not* use `fetchWithAuth` (`SDK:Supabase/SupabaseClient.swift:269-272`). Unauthenticated
  endpoints send `Authorization: Bearer <publishable key>`. `authorizedExecute` (PUT /user) and the explicit headers
  of `/logout` and implicit `/user` set `Bearer <access_token>` (`SDK:Auth/Internal/APIClient.swift:68-79`).
* Every Auth request also gets `X-Supabase-Api-Version: 2024-01-01` (`SDK:Auth/Internal/APIClient.swift:54-56`,
  `SDK:Auth/Internal/Constants.swift:20,32`).

### 2.4 JSON coding per module

| Module | Request encoder | Response decoder |
|---|---|---|
| Auth | `JSONEncoder.supabase()` + `.convertToSnakeCase` (`SDK:Auth/Defaults.swift:13-17`). Synthesized Codable ⇒ **nil optionals omitted** | `JSONDecoder.supabase()` + `.convertFromSnakeCase` (`:20-24`) |
| PostgREST | `JSONEncoder.supabase()`, **no key strategy** (`SDK:PostgREST/Defaults.swift:18-28`). The app's param structs already use snake_case names | `JSONDecoder.supabase()`, no key strategy. Keys must match the app's Swift names or CodingKeys exactly |
| Storage | `defaultStorageEncoder` = snake case (`SDK:Storage/Codable.swift:13-17`) | `JSONDecoder.supabase()`, no key strategy (`:23-26`) |
| Functions | plain `JSONEncoder()` (`SDK:Functions/Types.swift:57,71`) | not decoded by the app (§6) |

`HTTPRequest.urlRequest` adds `Content-Type: application/json` whenever a body exists and no Content-Type was set
(`SDK:Helpers/HTTP/HTTPRequest.swift:60-62`). Default per-request timeout is 60 s (`:29`). Functions uses 150 s
(`SDK:Functions/FunctionsClient.swift:53,310`).

### 2.5 Dates: what the SDK accepts and emits

`String.date` (`SDK:Helpers/DateFormatter.swift:10-37`) parses with `Date.ISO8601FormatStyle`
`year().month().day().dateTimeSeparator(.standard).time(includingFractionalSeconds: true)`, then falls back to the same
without fractions. Results of the same code compiled locally **[verified empirically]**:

| Input | Parsed as |
|---|---|
| `2024-01-01T12:00:00.123456Z` | 12:00:00Z (fraction accepted, 6 digits OK) |
| `2024-01-01T12:00:00Z` | 12:00:00Z |
| `2024-01-01T12:00:00.123456+00:00` | 12:00:00Z |
| `2024-01-01T12:00:00+07:00` | **12:00:00Z (offset ignored: wrong by 7 h)** |
| `2024-01-01T12:00:00` | 12:00:00Z |
| `2024-01-01 12:00:00+00` (Postgres text) | **nil ⇒ DecodingError** |
| `2024-01-01` | **nil ⇒ DecodingError** |

**Rule:** every `Date`-typed field the SDK decodes (User/Identity/Factor/FileObject dates) must be ISO-8601 with a
`T` separator, in UTC. Prefer `...Z` or `+00:00`. Encoding emits `2023-11-14T22:13:20.250` (UTC, no zone)
(`SDK:Helpers/Codable.swift:34-49`), but no request the app makes contains a SDK-encoded Date.

The app's own payloads parse timestamps with `ISO8601DateFormatter` `[.withInternetDateTime, .withFractionalSeconds]`,
falling back to no fractions. This parser **does** honour offsets (`APP:Data/Cloud/CloudWire.swift:136-142`,
`APP:Data/Cloud/CloudSharing.swift:25-33`). Postgres `to_jsonb(timestamptz)` output (`2026-10-26T10:00:00.123456+00:00`)
is fine there.

### 2.6 UUIDs and nil

`JSONEncoder` encodes `UUID` as `uuidString`, which is uppercase: `{"p_id":"3FA85F64-5717-4562-B3FC-2C963F66AFA6"}`.
The filter value is also `uuidString` (`SDK:PostgREST/PostgrestFilterValue.swift:53-54`). A synthesized `Encodable`
omits nil optionals: `P(p_id:…, p_after_id:nil, p_api_version:nil)` encodes as `{"p_id":"…"}`
**[verified empirically]**. UUID decoding accepts lowercase and uppercase.

### 2.7 Query-string escaping

PostgREST/Auth/Storage query items are percent-encoded with `urlQueryAllowed − ":#[]@!$&'()*+,;="`
(`SDK:Helpers/FoundationExtensions.swift:35-91`). `/` and `?` are not escaped. Example:
`redirect_to=babycare%3A//auth-callback`. The OAuth authorize URL is built with `URLComponents.queryItems` instead
(`SDK:Auth/AuthClient.swift:1598-1641`), giving `redirect_to=babycare://auth-callback`.

### 2.8 Retries (the server sees duplicates)

* **Auth:** `RetryRequestInterceptor` with methods `{DELETE, GET, HEAD, OPTIONS, PUT, TRACE} ∪ {POST}`
  (`SDK:Auth/Internal/APIClient.swift:11-17`). It retries on HTTP `408, 500, 502, 503, 504, 520–524, 530` or on
  transient `URLError`s (`SDK:Helpers/HTTP/RetryRequestInterceptor.swift:29-52`). `retryLimit 2` with `retryCount`
  starting at 1 means **at most one retry, after 1 s** (`:113,144-155`). So `POST /token?grant_type=refresh_token`,
  `/signup`, `/recover`, `/resend`, `/logout`, and `PUT /user` may arrive twice. Refresh-token rotation needs a
  reuse grace window, or a lost 5xx response becomes `refresh_token_already_used`, which forces a sign-out.
* **PostgREST:** only `GET`/`HEAD`. It retries on any network error, or on HTTP **503 / 520** only. Up to 3 retries
  with 1 s, 2 s, 4 s delays, adding header `X-Retry-Count: <n>` (`SDK:PostgREST/PostgrestBuilder.swift:205-243,260-286`).
  RPC (POST) is never retried. Don't answer a deterministic GET error with 503.
* **Storage, Functions:** no retry interceptor (`SDK:Storage/StorageApi.swift:77-85`,
  `SDK:Functions/FunctionsClient.swift:114-119`).

---

## 3. Auth (`/auth/v1`, GoTrue-compatible)

### 3.1 Endpoints the app reaches

| # | App call (file:line) | HTTP | Path + query | Auth header | Body (keys, nil omitted) | Success decode |
|---|---|---|---|---|---|---|
| A1 | `signUp(email:password:redirectTo:captchaToken:)` `APP:ViewModels/SessionViewModel.swift:345` | POST | `/auth/v1/signup?redirect_to=babycare%3A//auth-callback` | `Bearer <key>` | `email`, `password`, `code_challenge`, `code_challenge_method`, [`gotrue_meta_security:{captcha_token}`] (`SDK:Auth/AuthClient.swift:377-410`, `Types.swift:57-66`). `data`, `phone`, `channel` absent | 2xx → `AuthResponse` (Session **or** User) (`:444-456`) |
| A2 | `resend(email:type:.signup,emailRedirectTo:)` `SessionViewModel.swift:367` | POST | `/auth/v1/resend?redirect_to=…` | `Bearer <key>` | `type:"signup"`, `email`, `code_challenge`, `code_challenge_method`, [`gotrue_meta_security`] (`AuthClient.swift:1218-1249`, `Types.swift:1220-1226`) | any 2xx, body ignored |
| A3 | `signIn(email:password:captchaToken:)` `SessionViewModel.swift:343` | POST | `/auth/v1/token?grant_type=password` | `Bearer <key>` | `email`, `password`, [`gotrue_meta_security`] (`AuthClient.swift:464-483`, `Types.swift:35-55`) | 2xx → `Session` (`:577-587`) |
| A4 | auto/lazy refresh (§3.8) | POST | `/auth/v1/token?grant_type=refresh_token` | `Bearer <key>` | `refresh_token` (`SDK:Auth/Internal/SessionManager.swift:88-100`) | 2xx → `Session`, emits `.tokenRefreshed` |
| A5 | `signInWithIdToken(OpenIDConnectCredentials(provider:.apple,idToken:nonce:))` `SessionViewModel.swift:394` | POST | `/auth/v1/token?grant_type=id_token` | `Bearer <key>` | `provider:"apple"`, `id_token`, `nonce` (raw), **`link_identity:false`** (synthesized from `var linkIdentity = false`, `Types.swift:449-499`; verified encoding `{"id_token":"x","link_identity":false,"nonce":"n","provider":"apple"}`). `access_token`, `gotrue_meta_security` absent | 2xx → `Session` |
| A6 | `signInWithOAuth(provider:.google, redirectTo:)` `SessionViewModel.swift:380` | (browser) GET | `/auth/v1/authorize?provider=google&redirect_to=babycare://auth-callback&code_challenge=<43ch>&code_challenge_method=s256` | — (opened in ASWebAuthenticationSession) | — | browser must end at `babycare://auth-callback?code=…` |
| A7 | PKCE exchange (after A6 or an email link) | POST | `/auth/v1/token?grant_type=pkce` | `Bearer <key>` | `{"auth_code": "<code>", "code_verifier": "<verifier>" \| null}` (`AuthClient.swift:735-765`). `[String:String?]` encodes a missing verifier as JSON `null` | 2xx → `Session`, emits `.signedIn` |
| A8 | `resetPasswordForEmail(_:redirectTo:captchaToken:)` `SessionViewModel.swift:356` | POST | `/auth/v1/recover?redirect_to=…` | `Bearer <key>` | `email`, `code_challenge`, `code_challenge_method`, [`gotrue_meta_security`] (`AuthClient.swift:1471-1500`, `Types.swift:837-842`) | any 2xx, body ignored |
| A9 | `update(user: UserAttributes(password:))` `SessionViewModel.swift:427` | PUT | `/auth/v1/user` (no `redirect_to`: neither passed nor configured) | `Bearer <access_token>` | `{"password": "..."}`. No PKCE fields: they are added only when `email` is set (`AuthClient.swift:1307-1336`) | 2xx → **`User`** (not Session). Emits `.userUpdated` |
| A10 | `signOut(scope: .local)` `SessionViewModel.swift:438,464` | POST | `/auth/v1/logout?scope=local` | `Bearer <access_token>` | **no body** (so no Content-Type) | any 2xx. 401/403/404 are swallowed (`AuthClient.swift:1092-1118`) |
| A11 | `GET /auth/v1/user` | GET | `/auth/v1/user` | `Bearer <access_token>` | — | `User`. **Not called by the app** (implicit flow and `setSession` only). The apple-token Edge Function calls the server-side equivalent (`supabase.auth.getUser(jwt)`, `SB:functions/apple-token/index.ts:58-60`) |

Captcha: `AuthCaptchaEnabled` is `false` in `Configuration/Info.plist:5-6` and read at
`APP:Views/Profile/AuthCaptchaView.swift:38-49`, so `gotrue_meta_security` is currently never sent. If it is enabled,
it is `{"captcha_token":"…"}` (`Types.swift:502-512` + snake case).

PKCE values (`SDK:Auth/AuthClient.swift:1564-1578`, `SDK:Auth/Internal/PKCE.swift:10-37`): the verifier is 64 random
bytes in base64url without padding (86 chars). The challenge is base64url(SHA-256(verifier)) without padding
(43 chars). The method string is **lowercase `"s256"`**. The verifier is stored in the Keychain under
`"babycare.session-code-verifier"` (`SDK:Auth/Internal/CodeVerifierStorage.swift:12`). This is a **single slot**: every
A1/A2/A6/A8 overwrites it, and a successful A7 clears it (`AuthClient.swift:759`).

### 3.2 Error format and how the SDK reads it

Any non-2xx response → `APIClient.handleError` (`SDK:Auth/Internal/APIClient.swift:81-131`). The body is decoded as
`_RawAPIErrorResponse { msg?, message?, error_description?, error?, code: String?, error_code: String?, weak_password?: {reasons?: [String]} }`
(`:144-159`, snake-case decoder).

* **Every one of these keys must have the right type if present.** A numeric `code` (old GoTrue `{"code":400}`)
  breaks the decode. The result is then `AuthError.api(message:"Unexpected error", errorCode:.unexpectedFailure)`.
* Error-code choice: if the response header `X-Supabase-Api-Version` parses to a date ≥ 2024-01-01, the SDK uses
  `code`. Otherwise it uses `error_code` (`:96-105,134-140`). **Send both the header and string `code`.**
* `weak_password` (or code `weak_password`) → `AuthError.weakPassword(message, reasons)` (`:107-116`).
* Code ∈ {`session_not_found`, `session_expired`, `refresh_token_not_found`, `refresh_token_already_used`}
  (`:43-48`, `SDK:Auth/AuthError.swift:47-53`) → the SDK **deletes the stored session, emits `.signedOut`**, and
  throws `.sessionMissing` (`APIClient.swift:117-123`). This is the only way the backend can make the app sign out.
* Otherwise → `AuthError.api(message: msg ?? message ?? error_description ?? error ?? "Unknown", errorCode, data, response)`.

**How the app interprets auth errors:** it does **not** look at codes or messages at all.
* Sign-in, sign-up, reset, resend and update-password failures (`SessionViewModel.swift:359,369,428`) go through
  `authMessage` (`:483-486`). `URLError` → `"Không kết nối được dịch vụ đăng nhập. Hãy kiểm tra mạng."`. Anything
  else, including "Invalid login credentials", "Email not confirmed", "User already registered", weak password and
  rate limits → `"Chưa hoàn tất đăng nhập. Kiểm tra email, mật khẩu hoặc xác nhận email. Nếu gửi email thất bại, hãy thử lại sau hoặc kiểm tra cấu hình gửi email của project."`.
  No app code compares against `email_not_confirmed`, `invalid_credentials`, `user_already_exists` or their messages
  (searched across `APP:`). Recommended codes anyway: 400 `invalid_credentials`, 400 `email_not_confirmed`,
  422 `weak_password`, 429 `over_email_send_rate_limit`.
* An existing account on sign-up is detected **from a 200 response**, not from an error. See A1 below.
* Inside the cloud layer, `CloudError.normalize` maps **any** `AuthError` → `CloudError.signedOut`
  (`APP:Data/Cloud/SupabaseRemote.swift:76`) and `URLError` (not cancelled) → `.offline` (`:83`).
* Apple: any throw → `"Không thể đăng nhập bằng Apple. Hãy thử lại hoặc dùng email và mật khẩu."`
  (`SessionViewModel.swift:396,403-405`).
* Google: an `NSError` with domain `"com.apple.AuthenticationServices.WebAuthenticationSession"` and code `1` (user
  cancelled) is silent. Anything else → `"Không thể đăng nhập bằng Google. Hãy thử lại hoặc dùng email và mật khẩu."`
  (`:381-385`).
* Callback URL failures → `"Liên kết không còn hiệu lực. Hãy yêu cầu email mới."` (`:420-421`).
* Sign-out network failure → `"Đã thoát trên thiết bị. Chưa liên hệ được server để thu hồi phiên từ xa."` (`:438-439`).
  The local session is removed *before* the request (`SDK:Auth/AuthClient.swift:1098-1101`).

### 3.3 Response shapes (snake_case on the wire)

**Session** (synthesized `Decodable`, `SDK:Auth/Types.swift:69-147`):

| key | type | required |
|---|---|---|
| `access_token` | string | **yes** |
| `token_type` | string (`"bearer"`) | **yes** |
| `expires_in` | number (seconds) | **yes** |
| `expires_at` | number (Unix seconds) | **yes**. Nothing computes it on these paths (only the implicit-URL path does, `AuthClient.swift:1013`) |
| `refresh_token` | string | **yes** |
| `user` | User | **yes** |
| `provider_token`, `provider_refresh_token` | string | no |
| `weak_password` | `{ "reasons": [string] }` (`reasons` required if the object is present, `Types.swift:1258-1261`) | no |

**User** (custom decoder, `SDK:Auth/Types.swift:290-315`):

| key | type | required |
|---|---|---|
| `id` | UUID string | **yes** |
| `aud` | string (`"authenticated"`) | **yes** |
| `created_at`, `updated_at` | ISO-8601 UTC (§2.5) | **yes** |
| `app_metadata`, `user_metadata` | object (null/absent → `{}`) | no |
| `email`, `phone`, `new_email`, `action_link`, `role` | string | no |
| `confirmation_sent_at`, `recovery_sent_at`, `email_change_sent_at`, `invited_at`, `confirmed_at`, `email_confirmed_at`, `phone_confirmed_at`, `last_sign_in_at` | ISO-8601 UTC | no |
| `identities` | `[Identity]` | no, **but the app reads its count after sign-up** |
| `is_anonymous` | bool (absent → false) | no |
| `factors` | `[Factor]` | no. If present, every element must be a valid Factor. Best to omit it or send `[]` |

**Identity** (`SDK:Auth/Types.swift:386-399`): required `id` (string; for Apple this must be Apple's `sub`, see §6.2),
`user_id` (UUID), `provider` (string). Optional `identity_id` (UUID, defaults to the zero UUID), `identity_data`
(object), `created_at`/`last_sign_in_at`/`updated_at` (ISO-8601).

**Factor** (only if you send `factors`, `Types.swift:871-889`): `id`, `factor_type`,
`status ∈ {"verified","unverified"}`, `created_at`, `updated_at` required. `friendly_name` optional.

**AuthResponse** (sign-up, `Types.swift:654-696`): the SDK first tries `try? Session`, then `try? User`. A malformed
Session therefore silently falls through to the User decode and errors out there.

What the app uses from these: `session.user.id` (account key, family id seed, cache path), `session.user.email`
(display and owner-email fallback), `response.session != nil` and `response.user.identities?.count` (sign-up
outcome), `accessToken` (bearer). See `SessionViewModel.swift:112-113,159,175,221,346`.

### 3.4 Flow: email sign-up with confirmation link

1. App → A1: `POST /auth/v1/signup?redirect_to=babycare%3A//auth-callback`, body
   `{"email","password","code_challenge","code_challenge_method":"s256"}`.
2. The backend must answer **200** with one of three shapes. The app decides with `signupOutcome`
   (`SessionViewModel.swift:472-481`):
   * **Session JSON** (auto-confirm) → `.signedIn`. The SDK stores it and emits `.signedIn`.
   * **User JSON at top level** (not wrapped), no session, `identities` non-empty or absent →
     `.confirmationPending`. The app stores `pendingSignupEmail` and shows
     `"Đã gửi email tới {0}. Bấm liên kết trong email để xác minh tài khoản."` (`:350-353`).
   * **User JSON with `"identities": []`**: this is the email-enumeration-protection shape for an already
     *confirmed* email → `.existingAccount` → `"Email này đã có tài khoản. Hãy đăng nhập hoặc dùng Quên mật khẩu."`
     (`:348-349`). The fake user still needs a valid `id`, `aud`, `created_at`, `updated_at`.
   * An existing *unconfirmed* email: GoTrue re-sends and returns the user with identities. Mirror that so the app
     keeps waiting for the email.
3. The backend stores a PKCE flow state: `code_challenge`, method `s256`, user, auth method "signup",
   `redirect_to` (allow-list: `babycare://auth-callback`, `SB:AUTH_SETUP.md:14,33`). It then emails a link to its
   own verify endpoint. The current template uses `{{ .ConfirmationURL }}`, see `SB:templates/`.
4. The user taps the link → browser `GET <backend>/auth/v1/verify?...` (server-side; the SDK is not involved).
   * Mark the email confirmed **at this step**. The code exchange may never happen: different device, or the verifier
     was overwritten by a later A2/A8. `SB:AUTH_SETUP.md` tells such users to sign in with their password instead.
   * On success: **303/302 to `babycare://auth-callback?code=<auth_code>`**.
   * On failure: redirect to `babycare://auth-callback?error=<e>&error_code=<c>&error_description=<d>` (query or
     fragment both work, §3.7).
5. iOS opens the app → `.onOpenURL` (`APP:Views/Profile/AccountView.swift:65`) → `handleCallback`
   (`SessionViewModel.swift:406-422`). The app requires `scheme == "babycare"` and `host == "auth-callback"`, then
   calls `client.auth.session(from: url)`.
6. SDK (PKCE): reads `code` → A7 `POST /auth/v1/token?grant_type=pkce` with `{"auth_code", "code_verifier"}`. The
   backend must check `base64url(sha256(code_verifier)) == code_challenge`, make the code single-use, and return a
   Session. The SDK stores it and emits `.signedIn`. The app's listener accepts it (§7.1).
7. Any failure (exchange error or `error` params) → `"Liên kết không còn hiệu lực. Hãy yêu cầu email mới."`.

### 3.5 Resend confirmation

A2: `POST /auth/v1/resend?redirect_to=babycare%3A//auth-callback`,
`{"type":"signup","email":"…","code_challenge":"…","code_challenge_method":"s256"}`. Response body is ignored; any
2xx means success → `"Đã gửi lại email xác thực tới {0}."` (`SessionViewModel.swift:361-370`). The new challenge
**replaces** the device's verifier, so the new email's flow state must use this new challenge. Links from earlier
emails then fail the exchange on this device. Email confirmation at `/verify` still works (§3.4 step 4).

### 3.6 Sign in with password

A3: `POST /auth/v1/token?grant_type=password`, `{"email","password"}` → Session. The SDK stores it and emits
`.signedIn` (`AuthClient.swift:577-587`). Errors as in §3.2. The app shows one generic message.

### 3.7 `session(from:)` and URL parsing (exact)

`extractParams` (`SDK:Auth/Internal/Helpers.swift:4-41`) merges fragment pairs first, then query pairs (**query wins**
on duplicate names). It `+`→space and percent-decodes, and drops pairs with an empty value.

* PKCE (this app): `isPKCEFlow` = `code` present, or `error_description`, or `error`, or (`error_code` and a verifier
  stored) (`AuthClient.swift:1584-1588`). Otherwise it throws
  `pkceGrantCodeExchange("Not a valid PKCE flow URL: …")` (`:971-975`).
  Error params present → throws `pkceGrantCodeExchange(message: error_description ?? "Error in URL with unspecified error_description.", error:, code:)`
  (`:1031-1038`). Then `code` → A7 (`:1040-1044`).
* Implicit (**not used**): needs `access_token`, `expires_in`, `refresh_token`, `token_type`, and optionally
  `expires_at`, `provider_token`, `provider_refresh_token`. It calls `GET /user` and emits `.signedIn`, then
  `.passwordRecovery` if `type == "recovery"` (`:979-1026`).

### 3.8 Refresh, expiry, auto-refresh, and JWT claims

* `auth.session` (used by every data request and by `loadAccount`) returns the stored session unless
  `expires_at - now < 30 s` (`SDK:Auth/Types.swift:143-146`, `SDK:Auth/Internal/Constants.swift:12`), in which case it
  refreshes (A4) (`SDK:Auth/Internal/SessionManager.swift:51-65`). Concurrent refreshes share one in-flight task
  (`:75-108`).
* Auto-refresh (main client only, `autoRefreshToken = true`): it starts on `UIApplication.didBecomeActive` and stops on
  `willResignActive` (`SDK:Auth/AuthClient.swift:266-315`). The tick runs every 30 s and refreshes when
  `Int((expires_at - now)/30) <= 3`, i.e. under about 120 s left (`SessionManager.swift:121-160`,
  `Constants.swift:14-15`). Tick errors are swallowed (`try?`).
* At start-up, with `emitLocalSessionAsInitialSession: true`, the stored session (even an expired one) is emitted as
  `.initialSession`. If it is expired, a background refresh runs, and that refresh emits `.tokenRefreshed` or
  `.signedOut` (`AuthClient.swift:1527-1541`).
* **JWT:** on the paths the app uses, the SDK **never decodes the access token**. Expiry comes only from the JSON
  `expires_at`. The only decoders are `setSession` (`AuthClient.swift:1063`), MFA AAL (`AuthMFA.swift:173`) and
  `getClaims` (`AuthClient.swift:1722`), and none is called by the app. `expires_in` is stored but not used for
  scheduling. Keep JWT `exp == expires_at`, because the backend's own APIs judge expiry by `exp`. The claims are a
  backend-internal matter: the existing SQL uses `auth.uid()` (`sub`) and role `authenticated` (§8).
* Refresh errors: cleanup codes (§3.2) → sign-out. Any other `AuthError` → the app maps it to `CloudError.signedOut`
  and shows `"Phiên đăng nhập đã kết thúc. Hãy đăng nhập lại."` while the stale session stays stored.
  `URLError` → offline mode (`SessionViewModel.swift:181-195`).

### 3.9 Password recovery (as the code behaves today)

1. A8 `POST /auth/v1/recover?redirect_to=babycare%3A//auth-callback`,
   `{"email","code_challenge","code_challenge_method":"s256"}`. The body is ignored. The app always shows
   `"Nếu tài khoản tồn tại, bạn sẽ nhận được email đặt lại mật khẩu."` (`SessionViewModel.swift:355-357`). Return 200
   for unknown emails too.
2. The email link → backend `/verify` (type recovery) → **must** redirect to `babycare://auth-callback?code=<auth_code>`.
3. App → `session(from:)` → A7 → `.signedIn` only. **The SDK does not emit `.passwordRecovery` in PKCE mode, and
   `type` is ignored** (`AuthClient.swift:1028-1045`). So `needsNewPassword` stays false and `NewPasswordView`
   (`APP:Views/Profile/AccountView.swift:40`) is never shown. The user simply ends up signed in. Sending an
   implicit-style fragment instead would make the SDK throw "Not a valid PKCE flow URL".
   *Fix options (app-side, out of scope for the backend):*
   * Have the backend append a marker, e.g. `babycare://auth-callback?code=…&type=recovery`. The SDK ignores the
     extra param. The app checks it in `handleCallback` before or after `session(from:)` and sets `needsNewPassword`.
   * Or switch the client to `flowType: .implicit`, which changes every flow in this document.
4. Update the password: A9 `PUT /auth/v1/user` with `Bearer <access_token>`, body `{"password":"…"}` → **User** JSON
   → `.userUpdated`. The app then shows `"Đã đổi mật khẩu."` (`SessionViewModel.swift:423-429`).

### 3.10 Sign in with Apple (native id_token)

1. `AccountView` generates a 32-character raw nonce from `[0-9A-Za-z-._]`. It sends `request.nonce = sha256Hex(raw)`
   (lowercase hex) to Apple and requests the `.email` scope (`APP:Views/Profile/AccountView.swift:269-282`,
   `APP:Services/AppleSignIn.swift:6-16`).
2. A5: `POST /auth/v1/token?grant_type=id_token`,
   `{"provider":"apple","id_token":"<Apple JWT>","nonce":"<RAW nonce>","link_identity":false}`.
3. The backend must verify the token against Apple's JWKS, check `iss = https://appleid.apple.com`, and check that
   `aud` is in the authorized client IDs (`com.vuthanhdo.BabyCare`, `SB:AUTH_SETUP.md:24`) and `exp`. It must check
   that **the token's `nonce` claim equals lowercase-hex SHA-256 of the raw `nonce` field**. It then finds or creates
   the user with identity `{provider:"apple", id:<Apple sub>}` and returns a Session.
4. The SDK stores it and emits `.signedIn`. If Apple supplied an `authorizationCode`, the app then calls the
   `apple-token` function with `{"action":"link","code":…}` (§6). Failures there are ignored.

### 3.11 Google via `signInWithOAuth` (browser + PKCE)

1. The SDK builds A6: `<url>/auth/v1/authorize?provider=google&redirect_to=babycare://auth-callback&code_challenge=<c>&code_challenge_method=s256`.
   There are no `scopes` or extra params, and no `skip_http_redirect` (`AuthClient.swift:776-820,1590-1642`).
2. It opens `ASWebAuthenticationSession(url:, callbackURLScheme: "babycare")`. The scheme comes from `redirectTo`,
   because `configuration.redirectToURL` is nil. The default `configure` is a no-op, so the session is not ephemeral
   and shares Safari cookies (`AuthClient.swift:837-891`).
3. The backend `/authorize` validates `redirect_to` against the allow-list, stores a flow state (challenge, provider,
   redirect_to), and 302s to Google with `redirect_uri=<backend>/auth/v1/callback` and its own `state`. Google's OAuth
   client must list that new callback URI (currently `https://cxlqvuqloaokzmaewvdy.supabase.co/auth/v1/callback`,
   `SB:AUTH_SETUP.md:9-11`). Google → `GET /auth/v1/callback?code&state` → the backend exchanges the code with Google,
   upserts the user and identity (`provider:"google"`), and **302s to `babycare://auth-callback?code=<auth_code>`**
   (errors: `?error=…&error_description=…`).
4. The session completes on the first navigation to a `babycare:` URL. That URL is returned to the SDK directly, not
   through `onOpenURL`. The SDK runs `session(from:)` → A7 → `.signedIn` (`AuthClient.swift:817-819`).
5. App errors: see §3.2. Note that the `error` params in the callback make the SDK throw. The app then shows the
   Google failure message, not a silent cancel.

### 3.12 Sign-out

A10: `POST /auth/v1/logout?scope=local`, `Authorization: Bearer <access_token>`, no body. The SDK has already
removed the session and emitted `.signedOut` (`AuthClient.swift:1092-1118`). Return 204 (any 2xx). 401/403/404 are
ignored. `scope=local` means "revoke only this session" (GoTrue semantics). The app never uses `global` or `others`.
After account deletion the app calls it again with `try?` (`SessionViewModel.swift:464`). The user row is already
gone (`babycare_delete_account` deletes `auth.users`), so answer 401/404, which the SDK ignores.

---

## 4. PostgREST (`/rest/v1`)

### 4.1 Request shape (all calls)

* Headers: `Apikey`, `Authorization: Bearer <access_token>` (or `<key>` if no session, §2.3), `X-Client-Info`,
  **`Accept: application/json`** and **`Content-Type: application/json` on every request, GET included**
  (`SDK:PostgREST/PostgrestBuilder.swift:192-195`), and `X-Retry-Count` on GET retries.
* **Not sent:** `Prefer` (the app uses no count, insert, update or upsert, `PostgrestClient.swift:331-333` only sets
  it when `count` is given), `Range`/`Range-Unit` (`range()` uses `offset`/`limit` query params,
  `PostgrestTransformBuilder.swift:164-180`), and `Accept-Profile`/`Content-Profile` (`schema` is nil,
  `PostgrestBuilder.swift:197-203`).
* **The app makes no `insert`, `update`, `upsert` or `delete` through PostgREST.** Every write is an RPC.

### 4.2 RPC request (`SDK:PostgREST/PostgrestClient.swift:294-367`)

`POST /rest/v1/rpc/<fn>`. The body is the params struct encoded with no key strategy (UUIDs uppercase, nil fields
omitted). `rpc(fn)` without params sends **no body** but still `Content-Type: application/json`
(`:328`, `NoParams` `:414`). The backend must treat an empty body as `{}`. No `Prefer: params=single-object` is sent:
each top-level JSON key is a named argument, and an omitted key means "use the SQL default".

### 4.3 Response handling (`SDK:PostgREST/PostgrestBuilder.swift:137-257`)

* 2xx + `.execute()` with no `.value`: the body is **ignored**, so 200 with any JSON, or 204, is fine.
* 2xx + `.execute().value`: the body is decoded as `T` with `JSONDecoder.supabase()` and **no key conversion**. A
  function returning `jsonb` must return the JSON value itself (object or array, unwrapped). A function returning
  `uuid` must return a JSON string (`"…"`). Top-level scalars decode fine **[verified empirically]**. A GET on a table
  returns a JSON **array**.
* Non-2xx: decode `PostgrestError { message: String (required), code: String?, details: String?, hint: String? }`
  (`SDK:Helpers/SharedModels/PostgrestError.swift:10-41`) → throw it. If the decode fails →
  `HTTPError(data, response)` (`SDK:Helpers/SharedModels/HTTPError.swift:17-34`). The SDK does not look at the HTTP
  status beyond 2xx (and 503/520 for GET retries). Reference only: PostgREST's usual mapping is P0001→400,
  42501→401/403, 23505→409, missing function PGRST202→404.

### 4.4 Every RPC the app calls

Result type "∅" means `.execute()` (body ignored). Return types refer to `SB:migrations`.

| RPC | Called at | Body keys | SQL returns | App decodes as |
|---|---|---|---|---|
| `babycare_consent_status` | `APP:ViewModels/ConsentViewModel.swift:44`, also `SupabaseRemote.swift:240` | none | jsonb | `ConsentStatus {required:{terms_version,privacy_version,health_version: String}, accepted: ConsentRecord? (null OK), valid: Bool}`. `ConsentRecord` = `terms_version, privacy_version, health_version, terms_accepted_at, privacy_accepted_at, health_accepted_at: String, representative_confirmed: Bool, representative_confirmed_at, created_at: String` (`ConsentViewModel.swift:5-34`) |
| `babycare_accept_consent` | `ConsentViewModel.swift:51-53` | `p_terms_version, p_privacy_version, p_health_version` (strings), `p_terms_accepted, p_health_accepted, p_representative_confirmed` (all `true`) | jsonb | `ConsentStatus` |
| `babycare_my_families` | `APP:Data/Cloud/CloudSharing.swift:154` | none | jsonb array | `[{id: UUID, name, revision: Int, role: "owner"\|"caregiver"\|"viewer", created_by: UUID, owner_email, member_count: Int}]` (`CloudSharing.swift:35-46`). **PGRST202 → nil → legacy table query §4.5 Q2** |
| `babycare_create_family` | `APP:ViewModels/SessionViewModel.swift:174-175` | `p_id` (= user id), `p_name: "Hồ sơ của tôi"` | uuid | `UUID`, i.e. body `"<uuid>"` |
| `babycare_family_sharing` | `CloudSharing.swift:158-160` | `p_family_id` | jsonb | `{role, created_by, members:[{user_id, email, role, joined_at}], invites:[{id, role, expires_at}]}` (`:48-91`, timestamps parsed with offsets) |
| `babycare_create_invite` | `:161-164` | `p_family_id, p_role` | jsonb | `{id, role, expires_at, code}` (`:94-103`) |
| `babycare_accept_invite` | `:165-168` | `p_code` (8 uppercase alphanumerics) | jsonb | `{status: joined\|already_member\|invalid\|expired\|revoked\|used\|family_full\|rate_limited, family_id?, owner_email?, role?}` (`:105-125`) |
| `babycare_revoke_invite` | `:169-172` | `p_invite_id` | boolean | ∅ |
| `babycare_set_member_role` | `:173-176` | `p_family_id, p_user_id, p_role` | boolean | ∅ |
| `babycare_remove_member` | `:177-179` | `p_family_id, p_user_id` | boolean | ∅ |
| `babycare_leave_family` | `:180-182` | `p_family_id` | boolean | ∅ |
| `babycare_apply` | `APP:Data/Cloud/SupabaseRemote.swift:208` | `p_operation_id, p_family_id, p_changes:[{entity, id, baby_id? (omitted if nil), expected_version, data:{…}, deleted}], p_api_version: 1` (`APP:Data/Cloud/CloudWire.swift:34-47`) | jsonb | `CloudReceipt {operation_id: UUID, revision: Int, records:[{entity, id: UUID, version: Int}]}` (`CloudWire.swift:48-53`) |
| `babycare_read_page` | `SupabaseRemote.swift:327,330` | `p_family_id, p_entity, p_at_revision, p_limit: 200`, `p_after_id` (**omitted on the first page**), `p_api_version: 2`. **On PGRST202 the app retries without `p_api_version`** | jsonb | `{revision: Int, rows:[{…}], next_after_id: UUID?}` (`:320`). Row values must be JSON string/number/bool/null. `version` must be an integral number ≥1, `deleted_at` must be `null` for live rows, and timestamps are strings (`CloudWire.swift:3-11,129-210`) |
| `babycare_begin_baby_deletion` | `SupabaseRemote.swift:225` | `p_family_id, p_baby_id` | boolean | ∅ (PGRST202 ignored) |
| `babycare_delete_baby` | `:230` | `p_family_id, p_baby_id` | boolean | ∅ |
| `babycare_delete_account` | `SessionViewModel.swift:452` | none | boolean | ∅ |
| `babycare_send_feedback` | `APP:Data/Cloud/CloudFeedback.swift:30-32` | `p_id, p_kind: bug\|suggestion\|other, p_message, p_allow_contact, p_context:{app_version, build, os_version, device, language, storage}, p_attachments:[path…]` (`APP:Domain/CareFeedback.swift:46-58`) | jsonb | ∅ |
| `babycare_feature_board` | `APP:Data/Cloud/CloudFeatures.swift:48` | none | jsonb array | `[{id, title, details, status: pending\|open\|planned\|done\|declined, votes: Int, voted: Bool, mine: Bool}]` (`:20-29`) |
| `babycare_submit_feature` | `:53` | `p_id, p_title, p_details` | jsonb | ∅ |
| `babycare_toggle_feature_vote` | `:57` | `p_request_id` | jsonb | `{voted: Bool, votes: Int}` (`:31-34`) |
| `babycare_report_feature` | `:61` | `p_request_id` (SQL default for `p_reason`) | boolean | ∅ |

### 4.5 Every table query the app makes (exact URLs; params appear in this order)

| # | Called at | Request | Decodes |
|---|---|---|---|
| Q1 | `SupabaseRemote.swift:314,337` | `GET /rest/v1/families?select=*&id=eq.<UUID-UPPER>` | `[{id, name, revision: Int}]`, extra columns ignored. Empty array → `accessDenied` |
| Q2 | `SessionViewModel.swift:217` (only after `babycare_my_families` → PGRST202) | `GET /rest/v1/families?select=*&order=id.asc.nullslast&offset=<n>&limit=200` | same, paged until fewer than 200 |
| Q3 | `SupabaseRemote.swift:105-107` (account deletion) | `GET /rest/v1/families?select=id&created_by=eq.<UUID>&order=id.asc.nullslast&offset=<n>&limit=500` | `[{id}]` |
| Q4 | `:137-139` (baby deletion) | `GET /rest/v1/media_assets?select=object_path&family_id=eq.<UUID>&baby_id=eq.<UUID>&order=object_path.asc.nullslast&offset=<n>&limit=500` | `[{object_path}]` |
| Q5 | `:141-143` (account deletion) | `GET /rest/v1/media_assets?select=object_path&family_id=eq.<UUID>&order=object_path.asc.nullslast&offset=<n>&limit=500` | `[{object_path}]` |
| Q6 | `:121` (account deletion) | `GET /rest/v1/app_feedback?select=attachments` (no filter: RLS `own_feedback` limits it to the caller, `SB:migrations/202610270013_feedback.sql:24`) | `[{attachments: [String]}]`. Error code `42P01` or `PGRST205` → skipped (`:122-124`) |

Builders: `select` → `select=<cols, whitespace stripped>` (`SDK:PostgREST/PostgrestQueryBuilder.swift:79-110`).
`eq` → `<col>=eq.<raw>` (`PostgrestFilterBuilder.swift:218-227`). `order(col)` →
`order=<col>.asc.nullslast` (`PostgrestTransformBuilder.swift:103-128`). `range(from:to:)` → `offset=<from>`,
`limit=<to-from+1>` (`:164-180`). `offset`/`limit` must behave like PostgREST.

### 4.6 How the app interprets PostgREST errors (`CloudError.normalize`, `APP:Data/Cloud/SupabaseRemote.swift:37-75`, in order)

| Condition (`code` = SQLSTATE or PGRST code, `message` exact) | Result |
|---|---|
| `message == "CONSENT_REQUIRED"` (raised as P0001, `SB:migrations/202609180008_user_consent.sql:56-63`) | `CloudError.consentRequired` |
| `P0001` + `"Baby limit reached"` | invalidInput `"Bạn chỉ có thể tạo tối đa 4 hồ sơ bé."` |
| `40001` or `23505` | `CloudError.conflict` |
| `42501` + `"Write access denied"` | rejected `"Bạn chỉ có quyền xem trong gia đình này nên thay đổi chưa được lưu."` |
| `42501` + `"Owner access required"` | rejected `"Chỉ chủ gia đình mới làm được việc này."` |
| `P0001` + `"Cannot leave own family"` | rejected `"Đây là gia đình của tài khoản bạn nên không thể rời đi."` |
| `P0001` + `"Too many suggestions"` | rejected `"Bạn đã gửi 5 đề xuất hôm nay. Hãy gửi tiếp vào ngày mai."` |
| `P0001` + `"Not open for votes"` | rejected `"Đề xuất này không còn nhận bình chọn."` |
| `P0001` + `"Too much feedback"` | rejected `"Bạn đã gửi 10 góp ý trong 1 giờ qua. Hãy thử lại sau ít phút."` |
| `P0001` + `"Family is full"` | rejected `"Gia đình này đã đủ 6 thành viên."` |
| `P0001` + `"Too many open invites"` | rejected `"Đang có 5 lời mời chưa dùng. Hủy bớt rồi tạo mã mới."` |
| `42501` (any other message), `PGRST301`, `PGRST302` | `CloudError.accessDenied`. Removed-member handling (`APP:ViewModels/BabyCareViewModel.swift:109-112,161`) |
| `PGRST202` | invalidInput `"Server chưa có hàm mà app cần. Hãy áp dụng migration Supabase mới nhất rồi thử lại. ({0})"` |
| `code` starts with `22` or `23`, or is `P0001` | `CloudError.rejected("Cloud từ chối dữ liệu ({code}: {message}). Hãy kiểm tra thông tin rồi thử lại.")`. The outbox **drops** the write |
| any other PostgrestError | `CareDataError.invalidInput(same text)`. The write stays queued |
| `URLError` (not cancelled) | `CloudError.offline` |
| `HTTPError` (non-JSON body), `FunctionsError` | **returned unchanged**: not offline, not signed-out |

Special handling done before `normalize`:
* `fetch` retries the whole read on `40001` up to 3 times, then gives up with `conflict`
  (`SupabaseRemote.swift:334,381-383`).
* `22023` + `"Unknown entity"` / `"Invalid read cursor"` on `vaccinations` → that entity is skipped
  (`:33-36,348-350`). `22023` + `"Unknown entity"` on an apply containing vaccinations → `vaccinationsUnavailable`
  (`:212-216`).
* `PGRST202` is a deliberate "server lacks this migration" signal in four places: `babycare_my_families`,
  `babycare_read_page` with `p_api_version`, `babycare_begin_baby_deletion`, and `babycare_consent_status` in
  `syncMedia` (`CloudSharing.swift:155`, `SupabaseRemote.swift:226,241,328`). If the new backend implements every
  function, it should only send PGRST202 for a truly unknown function or argument set (`message` naming it).
* Consent: any error from `babycare_consent_status` makes the app fall back to the local record
  (`ConsentViewModel.swift:99-102`).

---

## 5. Storage (`/storage/v1`)

Common: headers `Apikey`, `Authorization: Bearer <access_token>` (§2.3), `X-Client-Info`. No retries.
Non-2xx → decode `StorageError { statusCode: String?, message: String (required), error: String? }` with **exact
camelCase key `statusCode`** and **string** values (`SDK:Storage/StorageError.swift:16-37`, decoder
`SDK:Storage/Codable.swift:23-26`, `SDK:Storage/StorageApi.swift:115-123`). If that fails → `HTTPError`. Buckets used:
`babycare-media` (`SupabaseRemote.swift:153,273,366`) and `babycare-feedback` (`CloudFeedback.swift:11`).

### 5.1 Upload: `bucket.upload(path, data:, options:)` → `POST /storage/v1/object/<bucket>/<path>`

(`SDK:Storage/StorageFileApi.swift:136-211`, `StorageApi.swift:130-153`)
* Path: leading/trailing/duplicate slashes are cleaned, and the URL is `object/<bucketId>/<path>` (`:163-168,994-1007`).
  * Media: `babycare-media/<familyid>/<babyid>/<assetid>`, all lowercase, no extension (`APP:Data/Cloud/CloudMedia.swift:92`).
  * Feedback: `babycare-feedback/<userid>/<feedbackid>/<i>.jpg`, lowercase (`APP:Domain/CareFeedback.swift:46-48`).
* Headers: `Content-Type: multipart/form-data; boundary=alamofire.boundary.<16 hex>` (`MultipartFormData.swift:54-58,96`),
  `Cache-Control: max-age=<cacheControl>`, **`x-upsert: false`**. No `duplex` (nil).
* Body parts, in order:
  1. `Content-Disposition: form-data; name="cacheControl"` → `31536000` (media, `SupabaseRemote.swift:281`) or `3600`
     (feedback default, `CloudFeedback.swift:25`).
  2. `Content-Disposition: form-data; name=""; filename="<last path component>"` + `Content-Type: <mime>`. Media uses
     the asset mime: `image/jpeg|png|heic|webp` (`CloudMedia.swift:112-123`). Feedback uses `image/jpeg`. The raw
     bytes follow. Note the **empty field name** (`StorageFileApi.swift:27-54`, `MultipartFormData.swift:551-561`). No
     `metadata` part.
* Success: 2xx with JSON **`{"Key": "<bucket>/<path>", "Id": "<string>"}`** (both required, capitalised,
  `StorageFileApi.swift:158-161,176`). The app ignores the values but the decode must succeed.
* Object metadata the database depends on: `babycare_apply` requires a `storage.objects` row with
  `metadata->>'size' == byte_count` and `metadata->>'mimetype' == mime_type`
  (`SB:migrations/202609120006_vaccinations.sql:162-166`). Record size = byte length of the file part and mimetype =
  the part's Content-Type.
* Duplicate (`upsert=false`, object exists): send e.g. `{"statusCode":"409","error":"Duplicate","message":"The resource already exists"}`.
  Feedback treats `statusCode == "409"` or `message.lowercased().contains("exists")` as already uploaded
  (`CloudFeedback.swift:26`). For media the app downloads first and only uploads on 404 (`SupabaseRemote.swift:274-282`).

### 5.2 Download: `bucket.download(path:)` → `GET /storage/v1/object/<bucket>/<path>`

The plain `object/` route, **not** `object/authenticated/`. `render/image/authenticated` is used only with
TransformOptions, which the app doesn't pass (`StorageFileApi.swift:663-690`). There is no query. On 2xx the raw body
is returned. The app requires **byte-identical** content: `stored == upload.data` (`SupabaseRemote.swift:277`) and
`data.count == byteCount` (`:367`). Do not transcode or compress.
* Missing object: the app accepts **any** of `statusCode == "404"`, `error == "NoSuchKey"`, or
  `message.lowercased() == "object not found"` (`SupabaseRemote.swift:278-279`). Supabase sends HTTP 400 with
  `{"statusCode":"404","error":"not_found","message":"Object not found"}`.

### 5.3 Remove: `bucket.remove(paths:)` → `DELETE /storage/v1/object/<bucket>`

Body `{"prefixes": ["<path>", …]}`, at most 100 per call (`SupabaseRemote.swift:126-129,152-157`),
`Content-Type: application/json` (`StorageFileApi.swift:595-604`). Success: 2xx with a **JSON array** decodable as
`[FileObject]`, where each element is `{name: String (required), bucket_id?, owner?, id?: UUID, updated_at?, created_at?, last_accessed_at?: ISO-UTC, metadata?: object, buckets?: Bucket}`
(`SDK:Storage/Types.swift:398-471`). `[]` is valid (the result is ignored). Omit `buckets`.

### 5.4 Not used

Signed URLs, public URLs, list, move, copy, info, exists, update, and upload-to-signed-URL: the app calls none of them.

### 5.5 App interpretation of Storage errors (`SupabaseRemote.swift:77-82`)

* `message.contains("CONSENT_REQUIRED")` → `consentRequired`. This comes from the restrictive insert policy
  `require_media_consent` (`SB:migrations/202609180008_user_consent.sql:116-126`), so the backend must surface the
  RAISE text in `message`.
* `statusCode "401"`/`"403"` → `accessDenied`.
* `statusCode == nil` or starting with `"5"` → `offline`.
* anything else → invalidInput `"Không thể xử lý ảnh trên cloud ({0})."` (with `statusCode`).

---

## 6. Functions (`/functions/v1`) and `apple-token`

### 6.1 Wire

Called at `SessionViewModel.swift:401` (`{"action":"link","code":<authorizationCode>}`) and `:447`
(`{"action":"revoke"}`), both inside `try?`. This resolves to the `Void` overload, so **any 2xx is success and the
body is ignored. Every error is swallowed** (`SDK:Functions/FunctionsClient.swift:234-239`).
* `POST /functions/v1/apple-token` (method nil → `.post`, `:306`). No query (`region` nil → no `x-region` or
  `forceFunctionRegion`, `:313-317`). Timeout 150 s.
* Headers: `Apikey`, `X-Client-Info`, `Content-Type: application/json` (`SDK:Functions/Types.swift:69-71`), and
  `Authorization: Bearer <access_token>` from `adaptRequest`. Without a session there is no Authorization at all
  (new-format key, §2.3).
* Body: `JSONEncoder()` of `[String: String]`. Key order is not guaranteed.
* Response: non-2xx → `FunctionsError.httpError(code, data)`. A response header `x-relay-error: true` →
  `FunctionsError.relayError` (`FunctionsClient.swift:248-255`). Never send that header.

### 6.2 What `SB:functions/apple-token/index.ts` does

* Deployed with JWT verification on (`SB:AUTH_SETUP.md:28`). It accepts only POST, otherwise 405 `{"error":"POST only"}`
  (`:52`).
* Auth: takes `Authorization: Bearer`, calls `supabase.auth.getUser(jwt)` using `SUPABASE_URL` +
  `SUPABASE_SERVICE_ROLE_KEY` (`:53-60`). On failure → 401 `{"error":"Authentication required"}`.
* Body `{action, code}`. An empty or invalid JSON body becomes `{}` (`:62-67`).
* Apple client secret: an ES256 JWT with header `{alg:"ES256", kid: APPLE_KEY_ID}`, `iss = APPLE_TEAM_ID`,
  `sub = APPLE_CLIENT_ID`, `aud = "https://appleid.apple.com"`, `iat`, `exp = +1h`, signed with `APPLE_PRIVATE_KEY`
  (PKCS#8 PEM, `\n`-escaped allowed) (`:15-27`). Apple calls are form-encoded POSTs to `https://appleid.apple.com<path>`
  with `client_id` and `client_secret` plus params (`:29-40`).
* `action:"link"`:
  * `code` missing → 400 `{"error":"code required"}`.
  * `POST /auth/token` with `code` and `grant_type=authorization_code`. If that is not ok or has no `refresh_token`
    → 502 `{"error":"Apple token exchange failed","detail":<apple error or status>}`.
  * The `sub` of Apple's returned `id_token` must equal the user's identity `id` where `provider == "apple"`.
    Otherwise 403 `{"error":"Apple identity does not match this account"}` (`:94-98`).
  * Upsert `public.apple_tokens(user_id, refresh_token, updated_at=now)`. A DB error → 500 `{"error":msg}`.
  * Success → 200 `{"linked":true}` (`:86-109`).
* `action:"revoke"`:
  * Select `refresh_token` from `apple_tokens` where `user_id`. If none → 200
    `{"revoked":false,"reason":"no apple token for this user"}`.
  * `POST /auth/revoke` with `token=<refresh_token>` and `token_type_hint=refresh_token`. If not ok → 502
    `{"revoked":false,"error":"Apple revoke failed (<status>)"}`.
  * Otherwise delete the row → 200 `{"revoked":true}` (`:110-117`).
* `action:"diag"` → 200 `{present:{APPLE_TEAM_ID, APPLE_CLIENT_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY: bool}, pemLines, pemStartsWithHeader, clientSecret:"ok"|error}`
  (`:70-85`). The app never calls it.
* Any other action → 400 `{"error":"action must be link or revoke"}`. Exceptions → 500 `{"error":msg}`.
* Env/secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `APPLE_TEAM_ID` (`K8CNPV49X7`), `APPLE_CLIENT_ID`
  (`com.vuthanhdo.BabyCare`), `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (`SB:AUTH_SETUP.md:28`).
* Table: `public.apple_tokens(user_id uuid pk → auth.users on delete cascade, refresh_token text, created_at, updated_at)`.
  RLS is on, there is no anon/authenticated access, and only service_role may use it
  (`SB:migrations/202610190009_apple_tokens.sql`, `202610200010_apple_tokens_grant.sql:3`).
* Ordering in account deletion (`SessionViewModel.swift:442-471`):
  1. revoke
  2. Q3 + Q5 + storage removes (media)
  3. Q6 + feedback removes
  4. `babycare_delete_account`, which deletes the `auth.users` row
  5. `signOut(.local)`

---

## 7. Behaviour that depends on Supabase-specific client logic

### 7.1 Auth events and the app's listener

`SessionViewModel.start()` (`APP:ViewModels/SessionViewModel.swift:69-80`) iterates `client.auth.authStateChanges`.
Each subscription gets its own `INITIAL_SESSION` (`SDK:Auth/AuthClient.swift:330-367,1527-1541`). The emitter does
not replay earlier events to new listeners (`SDK:Auth/Internal/EventEmitter.swift:5-6`). For each `(event, session)`:
* `event == .passwordRecovery` → `needsNewPassword = true` (unreachable under PKCE, §3.9).
* If `session?.user.id == userID` and `phase != .starting`, the event is ignored. This is how `.tokenRefreshed` and
  `.userUpdated` are absorbed.
* Otherwise `accept(session)`: nil → `.signedOut`. Non-nil → consent RPC → families → family.

Events and who emits them:

| Event | Emitted by |
|---|---|
| `INITIAL_SESSION` | start-up |
| `SIGNED_IN` | A1 with session, A3, A5, A7 |
| `TOKEN_REFRESHED` | A4 |
| `USER_UPDATED` | A9 |
| `SIGNED_OUT` | A10 (local, before the request) or a cleanup error code |

`QuickLogPerformer` (widget/shortcut) also uses `SessionViewModel.shared.start()`
(`APP:Services/QuickLogPerformer.swift:36-37`), so there is still one client per process.

### 7.2 Session persistence (survives the URL change)

Keychain service `com.vuthanhdo.BabyCare.auth`, key `babycare.session` (session) and `babycare.session-code-verifier`.
The session is stored as plain `JSONEncoder` camelCase, which is internal (`SDK:Auth/Internal/SessionStorage.swift:55-70`).
`openDevice`/`openCloud` read `client.auth.currentSession` synchronously, with no network
(`SessionViewModel.swift:95-108`). **After the backend swap, existing installs still hold Supabase-issued tokens.**
See §9.

### 7.3 Deep links

`.onOpenURL` (`APP:Views/Profile/AccountView.swift:65`) → `handleCallback`. The app handles
`babycare://invite?code=XXXXXXXX` itself (`APP:Data/Cloud/CloudSharing.swift:198-210`), then
`babycare://auth-callback…` → `auth.session(from:)`. The app never calls `client.handle(url)`. The URL scheme
`babycare` is registered in `Configuration/Info.plist:7-16`.

### 7.4 `emitLocalSessionAsInitialSession: true`

The app starts from the stored session even when it is expired or offline. An expired one triggers a background
refresh. Offline start-up keeps the account and uses the cache (`SessionViewModel.swift:189-191`).

---

## 8. Server-side assumptions inherited from Supabase (beyond the HTTP wire)

The SQL in `SB:migrations` assumes:
* `auth.uid()` from the request JWT `sub`, role `authenticated` versus `anon` grants. Every RPC is granted to
  `authenticated` only, except `babycare_consent_requirements` (also `anon`).
* An `auth.users` table: foreign keys plus `email` lookups in `babycare_accept_invite`, `babycare_feature_board`,
  `babycare_send_feedback`, and `delete from auth.users` in `babycare_delete_account`
  (`202610260012_shared_care.sql`, approximately line 293).
* `storage.buckets` and `storage.objects` with RLS policies that run as the caller: `can_access_media`,
  `can_delete_media`, the `require_media_consent` restrictive policy, and the feedback-folder policies
  (`202609090001_babycare.sql:178-183`, `202609160007_privacy_deletion.sql:5-16`,
  `202609180008_user_consent.sql:116-126`, `202610270013_feedback.sql:26-33`).
* `babycare_apply` and `babycare_send_feedback` read `storage.objects` (`name`, `bucket_id`, `metadata.size`,
  `metadata.mimetype`). Storage authorization therefore has to stay inside Postgres, or be reimplemented with
  identical rules.
* Bucket limits: 5 MiB and the MIME allow-list `image/jpeg|png|heic|webp` for both buckets.
* `notify pgrst,'reload schema'`, which only matters for real PostgREST.
* The local cache path hard-codes the project ref `cxlqvuqloaokzmaewvdy` (`APP:Data/Cloud/CloudCache.swift:42`,
  `SessionViewModel.swift:456`). It is independent of the URL.
* `babycare_create_family` uses the **user id as the family id** (`SessionViewModel.swift:175`). User ids must be kept
  when migrating accounts, or existing families, consent keys and caches will not line up.

---

## 9. Migration risks and checks

1. **Stale Supabase sessions on existing installs.** If old JWTs fail verification, PostgREST answers
   `PGRST301`/`PGRST302` → `accessDenied` or an access-lost loop. An expired-JWT code such as `PGRST303` falls into
   the generic "invalidInput" branch, so the account error screen appears. The old refresh token then reaches the
   new `/token`. **Return 400 with `code: "refresh_token_not_found"` and header `X-Supabase-Api-Version: 2024-01-01`**
   so that the SDK signs out cleanly. Alternatively migrate users together with the same JWT secret and refresh tokens.
2. Refresh-token reuse window (auth POST retry, §2.8).
3. UTC-only timestamps in Auth/Storage JSON (§2.5).
4. String `statusCode` in Storage errors, and `{Key, Id}` on upload.
5. Empty-body RPC POSTs and uppercase UUIDs. Omitted keys mean SQL defaults (`p_after_id`, `p_api_version`,
   `p_reason`, `p_details`).
6. Don't use 503/520 for deterministic GET errors (they are retried 3× over about 7 s).
7. `/verify` must confirm the email even if the PKCE exchange later fails, and must redirect with `?code=`.
8. Google: register `<new backend>/auth/v1/callback` in the Google OAuth client.
   Apple: `aud = com.vuthanhdo.BabyCare` and nonce = SHA-256 hex.
9. Recovery UX (§3.9) needs an app change whatever the backend does.
10. Keep the API key format `sb_publishable_…`, or any non-`sb_` string. A JWT-style key is also sent as
    `Authorization: Bearer` to Functions when signed out.
