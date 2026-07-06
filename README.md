# SIYAM — Flutter Web port

This is the Flutter Web conversion of the `Design-SIYAM-Web-Application` React
project. This first pass sets up the **overall shell**: login, register, top
nav, sidebar, and the protected layout that wraps every inner page. All
content pages other than Dashboard are placeholders for now — Inventory
included — and are meant to be built out one at a time next.

## 1. Get the Flutter SDK project scaffolding

I can't run the Flutter SDK in this sandbox, so the platform boilerplate
(`android/`, `ios/`, full `web/` manifest & icons, etc.) isn't included —
just `lib/`, `pubspec.yaml`, and a minimal `web/index.html`. To finish the
scaffold on your machine:

```bash
# unzip / copy this folder somewhere, then inside it:
flutter create . --platforms web
flutter pub get
```

`flutter create .` will fill in the missing `web/` files (manifest.json,
icons, flutter_bootstrap.js) without touching the `lib/` folder or
`pubspec.yaml` you already have — just don't let it overwrite
`web/index.html` if it prompts you (keep the one provided here, or merge).

## 2. Plug in your Supabase project

Open `lib/core/supabase_config.dart` and replace the placeholders, or pass
them at build/run time so you don't hardcode secrets:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLISHABLE-OR-ANON-KEY
```

## 3. Add the RLS policies your schema needs

Your `users` table (and everything else) gets RLS auto-enabled the moment
it's created, per the trigger noted in your SQL file. Right now there are no
`CREATE POLICY` statements, so the app can authenticate but **can't read or
write `public.users` yet** — login/register will look like they "work" (auth
succeeds) but profile fetch/insert will fail silently into "unauthenticated".

At minimum, add these two policies to unblock the login/register flow built
here:

```sql
-- Let a signed-in user read their own profile row
create policy "Users can view own profile"
on public.users for select
to authenticated
using (auth.uid() = userid);

-- Let a signed-in user create their own profile row (used by Register)
create policy "Users can insert own profile"
on public.users for insert
to authenticated
with check (auth.uid() = userid);
```

Staff/manager accounts aren't self-service in this design (only donors can
register themselves) — you'll want to insert `staff`/`manager` rows directly
via the Supabase Studio dashboard for now, same as you were already doing for
test data.

You'll need equivalent `select`/`insert`/`update` policies on every other
table (`pet`, `item`, `donation`, etc.) before those pages can do real
CRUD — we can write those alongside each page as it gets built out.

## What's here

| Piece | File |
|---|---|
| Supabase init | `lib/main.dart`, `lib/core/supabase_config.dart` |
| Auth (sign in / sign up donor / sign out) | `lib/services/auth_service.dart` |
| Session/profile state + router redirects | `lib/state/auth_state.dart` |
| Routing (mirrors `routes.ts`) | `lib/routing/app_router.dart` |
| Login page | `lib/pages/login_page.dart` |
| Register page (donor sign-up) | `lib/pages/register_page.dart` |
| Public landing page | `lib/pages/landing_page.dart` |
| Sidebar (role-filtered nav, mirrors `Sidebar.tsx`) | `lib/widgets/side_nav.dart` |
| Top nav (breadcrumb, notifications, profile) | `lib/widgets/top_nav.dart` |
| Protected layout shell (mirrors `Layout.tsx`) | `lib/widgets/app_shell.dart` |
| Placeholder content pages | `lib/pages/*_page.dart` |
| Theme/colors ported from `default_shadcn_theme.css` | `lib/core/app_theme.dart` |

## Role-based nav

Sidebar items are filtered by role exactly like the original:
- **manager**: Dashboard, Animals, Suppliers, Reports, Audit Trail, Settings
- **staff**: Dashboard, Inventory, Medical, Donations, Reports
- **donor**: Dashboard, Donate Now, Donations
- shared: Profile, Notifications

## Next steps

Tell me which page to build out for real next (Inventory is the obvious
first candidate given your schema's `item` table) and I'll wire it up to
Supabase with actual CRUD, plus the RLS policies it needs.
