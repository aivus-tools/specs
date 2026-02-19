# AIVUS - Local Development Capsule

## Dev Environment

- Backend: Django 5.2 + PostgreSQL + Redis + Celery, runs ONLY in Docker
- Frontend: Next.js 15 (App Router) + Redux Toolkit + RTK Query + NextAuth.js
- Docker compose file: `Backend/aivus_backend/docker-compose.local.yml`
- Python 3.13 in Docker, locally 3.13.12
- NEVER run `npm run build` to check types - use `npx tsc --noEmit`
- If dev server breaks with CSS 404: kill port 3000, rm -rf .next, npm run dev

## Architecture Notes

### HMAC Auth Middleware
- Frontend proxies `/service/*` to `/api/v1/*` through HMAC middleware
- Client-side code (components with `'use client'`) must use `/service/` routes (ApiRoute)
- Server-side code (NextAuth callbacks, server actions) uses `/api/v1/` routes (ApiPathname) with `API_URL = http://localhost:8000`
- Auth pages (`/auth/*`) do NOT have Redux Provider - cannot use RTK Query hooks there

### Redux Provider Scope
- `ReduxStore` wrapped in: `app/app/layout.tsx`, `app/public/layout.tsx`, `app/external/layout.tsx`
- NOT wrapped in: `app/auth/` - auth pages use plain fetch with `/service/` routes

### RTK Query API Slices
- `offersApi`, `templatesApi`, `sharesApi`, `userApi`, `profileApi`, etc. - separate API slices
- Tag invalidation does NOT cross between slices. To invalidate `offersApi` tags from `templatesApi`, use: `dispatch(offersApi.util.invalidateTags(['Offer']))`

### Offer Data Flow
- Backend `serialize_offer()` returns `{ id: "...", ... }` (NOT `offerId`)
- Backend `serialize_share_public()` returns flat `{ id, token, isActive, offer, vendor }` (no `share` wrapper, no `viewerRole`)
- `reconstruct_details_from_entries()` rebuilds offer details from `offer.metadata` + OfferEntry records
- `parse_offer_details_to_entries()` extracts metadata and saves to `offer.metadata`
- Copy offer correctly deep-copies `details`, `metadata`, and OfferEntry records

### Excel Export
- Template: `Frontend/public/template.xlsx` (English)
- Export code: `Frontend/src/helpers/excelExport/exportToExcel.ts` + `ExcelState.ts`
- Named ranges in template: `tableStart` (B31), `date` (C21), `videoCount` (C9)

## Pending Migration
- `projects` app has unmigrated changes: `Alter field status on brief`, `Alter field status on project`
- Only choices changed, no DB schema impact. Run when ready:
  ```
  docker compose -f docker-compose.local.yml exec django python manage.py makemigrations
  docker compose -f docker-compose.local.yml exec django python manage.py migrate
  ```

## Completed Work

### Sprint 1-5: Full MVP Implementation
- Vendor flow: Dashboard, Projects, Offers, Templates, Rate Cards, Estimation, Share, Excel Export
- Client flow: Dashboard, Brief creation (with chat), XLSX Upload, Offer Comparison, Comparison Analysis
- Auth: Login, Register, Email Confirmation, Forgot/Reset Password, Change Password, Profile/Settings
- Public offer view, external offer view

### QA Round 1-2: Bug Fixes
- Fixed across multiple rounds (security, data integrity, UX issues)

### QA Round 3: Bug Fixes (latest)

1. **Template apply creates empty offers** (Bug 1)
   - Root cause: `ApplyTemplateResponse` type had `offerId` but backend returns `id`. Also cross-API tag invalidation missing.
   - Fix: Changed type to `Offer`, used `newOffer.id`, added `dispatch(offersApi.util.invalidateTags(['Offer']))` in OfferTabs.tsx and Details.tsx

2. **ClientOfferTable crash - categories undefined** (Bug 2)
   - Root cause: `selectOfferDetails` can return undefined categories before data loads
   - Fix: Added `?? []` fallback for categories and subCategories

3. **PublicOfferView crash - type mismatch** (Bug 3)
   - Root cause: `PublicOfferData` type expected `{ share, offer, viewerRole }` but backend returns `{ id, token, isActive, offer, vendor }`
   - Fix: Updated type, changed component to use `vendor?.name`, derive viewerRole from session. Added `projectId` to backend serializer.

4. **Share toggle error handling** (Bug 4)
   - Logic was correct after analysis. Added async/await with error rollback to handleToggle in SharePopup.tsx

5. **Template.xlsx in Russian** (Bug 5)
   - Fix: Updated `Frontend/public/template.xlsx` from Russian to English

### Post-QA: Forgot/Reset Password Fix
- Auth pages (`'use client'`) were importing from `services/server/authService.ts` which uses `API_URL = http://localhost:8000`
- Browser fetch to localhost:8000 fails (CORS / wrong context)
- Fix: Replaced with direct fetch to `/service/auth/forgot-password` and `/service/auth/reset-password` using `ApiRoute`
- RTK Query mutations added to `userApi.ts` (forgotPassword, resetPassword) for future use in Redux-wrapped pages

## Known Issues
- `teamId = 'default-team-id'` hardcoded in useCreateProjectFlow.ts
- console.log + fakeData in RateTable.tsx
- Folder typo: `_componnets` instead of `_components`
- Double dots in filenames: `project.interface..ts`, `user.interface..ts`
- 5/8 dashboard columns show empty/zero values

## Key File Locations

### Frontend
- API routes: `src/constants/apiRoute.ts`
- App routes: `src/constants/appRoute.ts`
- RTK Query services: `src/services/client/`
- Server auth service: `src/services/server/authService.ts`
- Store slices: `src/store/slices/`
- Types: `src/types/`
- Locales: `src/locales/en.ts`, `src/locales/ru.ts`

### Backend
- Views: `aivus_backend/projects/api/views.py`
- Serializers: `aivus_backend/projects/api/serializers.py`
- Services: `aivus_backend/projects/services.py`
- Auth views: `aivus_backend/users/api/auth_views.py`
- URL config: `aivus_backend/projects/api/urls.py`, `aivus_backend/users/api/urls.py`

## Figma Node IDs
- Vendor Dashboard: 1066-19870
- Templates: 1067-19825
- Rates: 1481-21631
- Template select: 1543-3240
- Estimation: 4246-8142
- Client's Offer: 1454-21588
- Client Dashboard: 887-21948
- Brief form: 1543-3661
- Brief fields: 1543-3825, 1543-3880
- Comparison: 1623-3522
- XLSX Upload: 897-22647
