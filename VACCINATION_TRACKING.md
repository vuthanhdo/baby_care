# Vaccination Tracking

The baby profile links to vaccination history. Each record stores an administered date, vaccine name, dose number, clinic, notes, optional next appointment and optional reminder timestamp. History supports adding, editing and deleting. “Record next dose” atomically saves the new dose and clears the previous appointment/reminder. Appointment dates are entered by the user; no clinical schedule is calculated.

## Dependency / impact review

Graphify's existing graph guided inspection of CareDatabase, CareDataMutation, CareDataProvider, SwiftDataCareDataProvider, CloudMapping and CareReminderService. The graph predates vaccination symbols; new paths were verified in source/diff without rebuilding the graph.

- VaccinationEntryView → BabyCareViewModel.commit → provider.apply → CareDatabase.applying.
- Device: additive schema V2 → VaccinationEntity → transaction save. V1 model layouts remain unchanged. VaccinationEntity uses a babyID owner rather than modifying V1 relationships; the provider rejects orphaned ownership and reconciles removed records. Any future baby-delete feature must keep this cleanup.
- Cloud: CloudMapping → durable outbox → versioned babycare_apply → receipt. New record types use the existing provider/mutation flow and media behavior. The provider exposes vaccination availability for cloud compatibility.
- Notifications reconcile after durable persistence and after loads, using stable account/family/baby/type/record identifiers. Serial reconciliation prevents an older asynchronous scheduling operation from overwriting newer state. Permission failure does not undo the record. Past reminder times are retained for offline replay but not scheduled.
- Baby birth-date edits include vaccination history. Ending an illness does not cancel vaccination reminders.
- Missing vaccinations keys in old Codable snapshots/proposals decode to an empty collection; malformed present values still fail. Legacy JSON imports remain unchanged.

## Deployment and compatibility

Apply `supabase/migrations/202609120006_vaccinations.sql` after all preceding migrations and before releasing this client. It adds the table, RLS, indexes and RPC allowlist/validation support. Applied to the BabyCare Supabase project on 2026-09-13 through SQL Editor in one transaction. The deployed SQL has the same statements as the migration with condensed whitespace/comments; table, read RPC, write RPC and enabled RLS were verified afterward. This manual SQL Editor deployment does not register CLI migration history; reconcile migration history before a future CLI push rather than replaying table creation.

Older clients do not request vaccination rows, and unrelated entity writes retain those rows. Downgrading an installation that contains new vaccination outbox mutations is not supported. Back up local data before release/migration testing; never discard an outbox to resolve a decode error.

`supabase/tests/backend.sql` includes vaccination checks and rolls its fixtures back. Run it in a staging database after migration; local SQL execution requires a PostgreSQL/Supabase environment. The iOS tests exercise schema V1→V2, cache compatibility, cloud mapping, offline replay, ownership, notifications and UI CRUD.

Notifications are local to devices that load the account; this feature does not add server push delivery or an automatic vaccine recommendation engine. OS permission and delivery constraints still apply.

## Validation completed

- Xcode simulator build and the complete BabyCareTests target passed, together with VaccinationUITests CRUD.
- Final run: 203 passing test-case entries, zero failures (`/tmp/BabyCareVaccinationVerified.log`).
- V1 disk-store migration, vaccination reopening/edit/delete, old cached snapshot/outbox decoding, cloud offline retry, reminder relaunch identity, permission denial, invalidation and overlapping reconciliation tests passed.
- Vaccination history screenshot exported from the successful UI test was visually reviewed.
- `git diff --check` passed.
- Follow-up backend validation: 16 live transaction checks passed for vaccination CRUD/tombstones, read history, retry identity, validation, owner/viewer/cross-account access and RLS. Synthetic fixtures were rolled back; a separate query confirmed rollback. This was a focused SQL Editor check, not execution of the full backend.sql suite.
- Login compatibility follow-up: complete unit target passed with 207 test-case entries (`/tmp/BabyCareCloudCompatibilityTests.log`); after final cache/rebase changes, CloudProviderTests passed with 46 cases (`/tmp/BabyCareCloudCompatibilityFinal.log`).
- Existing Graphify graph was queried for affected provider, mutation, aggregate and reminder dependencies. It has not been regenerated and does not contain the new vaccination symbols.

## Login load regression (2026-09-13)

Confirmed cause: the live backend had neither the vaccination table nor vaccination support in babycare_read_page. SupabaseRemote requested every CloudMapping entity, so the old RPC rejected vaccination reads with 22023 / Invalid read cursor. That failed the initial provider load and moved BabyCareViewModel to failed, which ContentView displays as Unable to load data.

The backend migration resolves that deployed contract mismatch. The app also recognizes only the known legacy vaccination-entity rejection, loads other data, preserves cached vaccination history and disables vaccination writes until support is confirmed. The optional cached capability decodes old caches as unknown, requiring a successful supported fetch before new vaccination writes. Authorization errors still fail and purge inaccessible cache; they are not treated as missing feature support.

Existing queued vaccination operations survive an unsupported write response with their original operation IDs. Loading returns the cached optimistic data instead of discarding the outbox; loading again after backend upgrade flushes those operations. A queued unsupported operation can delay later FIFO writes until upgrade; the queue is deliberately retained. Conflict rebase preserves cached vaccination history and refuses to rebase vaccination mutations against an unsupported backend.

Impact review: existing graph nodes for load, SupabaseCareDataProvider, CloudSnapshot, CloudCacheState, flushQueuedWrites, rebaseQueue and CloudProviderTests were compared with the final diff. Capability handling additionally touches CareDataProvider, BabyCareViewModel, VaccinationView and localized messages. Existing SwiftData schema/reminder changes belong to the vaccination feature; this login fix adds no new SwiftData migration or notification mechanism. The existing graph remains unchanged and does not include new capability/vaccination symbols.
