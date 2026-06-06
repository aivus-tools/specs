---
name: aivus-frontend
description: "Use ALWAYS for frontend work in Aivus: writing or modifying React components, Next.js pages/routes, Redux state, RTK Query endpoints, vitest tests, Playwright E2E, antd UI, styles (CSS Modules + antd theme tokens), localization, NextAuth integration. Trigger for any work in /Frontend/ directory. Always invoke aivus-base alongside this skill for shared context. If task also touches backend API contract, also invoke aivus-backend. If task involves AI brief/chat UI, also invoke aivus-ai."
---

# Aivus Frontend — Next.js 15 + React 19 + RTK Query

**Перед началом**: если в этой сессии ещё не загружен `aivus-base` — вызови его через Skill tool сейчас. Базовые правила (тон, workflow, безопасность, MCP, источники истины) живут там, дублировать не буду.

## Стек

- Next.js 15.2.3 App Router
- React 19
- Redux Toolkit + RTK Query
- NextAuth.js
- UI: Ant Design 5 (`antd`, `@ant-design/nextjs-registry`, `@ant-design/v5-patch-for-react-19`) — единственная компонентная либа
- **Стили: antd ConfigProvider theme + `theme.useToken()` + CSS Modules.** styled-components выпилен полностью.
- Тесты: Vitest (jsdom) + Playwright

## Design system

### Источник правды — `Frontend/src/lib/themeConfig.ts`

Все дизайн-токены (цвета, spacing, radius, font sizes, motion) живут в `themeConfig.ts`. Подключаются через `<ConfigProvider theme={theme}>` в `app/layout.tsx`. В компоненте достаются через:

```typescript
import { theme } from 'antd';
const { token } = theme.useToken();
// token.colorPrimary, token.colorBgContainer, token.borderRadius, ...
```

**Никаких хардкод хексов в TSX.** Если видишь `#2288FF`, `#121b3e`, `#99a1b7` прямо в коде — это баг, должно быть через token.

### CSS aliases для .module.css — `globals.css`

В `.module.css` нельзя использовать `theme.useToken()`. Для них существует второй контракт — CSS variables, объявленные в `:root` файла `globals.css`. Они зеркалят значения из `themeConfig.ts` и подключаются через `var(--name)`:

- `--main` — `colorText` (#4b5675)
- `--main-dark` — `colorTextHeading` (#121b3e)
- `--gray` — `colorTextSecondary` (#5b6478)
- `--gray-light` — `colorTextTertiary` (#6e7689)
- `--blue` — `colorPrimary` (#2288ff)
- `--red` — `colorError` (#d63c22)
- `--green-darker` — `colorSuccess` (#a5c500)
- `--orange` — `colorWarning` (#fd8258)
- `--sider-bg` — `colors.siderBg` (#121b3e), для dark sider/drawer
- `--white`, `--beige`, `--bg-gray-page` — фоны

**AA-safe варианты для текста на белом** (используй вместо `--blue/--red/--green-darker/--orange` для links, labels, semantic-текста, чтобы пройти WCAG AA contrast):

- `--blue-text` — `colorPrimaryText` (#0a66c2), 6.0:1 vs `--blue` 3.48:1
- `--red-text` — `colorErrorText` (#b8311c)
- `--green-text` — `colorSuccessText` (#5f7300)
- `--orange-text` — `colorWarningText` (#a14216)

При изменении значения токена обновлять **оба места**: `themeConfig.ts` и `globals.css`. Это осознанный дубль; никаких хардкод хексов в `.module.css` быть не должно (stylelint правило `color-no-hex` ловит).

### Domain colors — `Frontend/src/app/globals.css`

CSS variables `--bg-blue-subtotal`, `--bg-blue-subsection`, `--bg-light-green`, `--compare-green` и т.д. — это **domain семантика** (статусы offer, цвета сравнения), не дизайн-токены. Подключаются в `.module.css` через `var(--name)`. Не утаскивать в `themeConfig.ts`.

## Структура `Frontend/src/`

```
src/
├── app/        Next.js App Router pages, layouts, route handlers
├── components/ переиспользуемые UI компоненты
│   └── layout/ AppShell — общий layout (header + sider + drawer + content slots)
├── modules/    фича-модули (briefs, offers, dashboards)
├── services/   RTK Query API endpoints
│   └── client/ *Api.ts файлы
├── store/      Redux store + slices
├── types/      TypeScript типы
├── locales/    en.ts, ru.ts словари
├── hooks/      кастомные хуки (useBreakpoint, useDocumentSize, useVoiceRecorder...)
├── styles/     breakpoints.ts, responsive.ts (token-like утилиты)
└── auth/       NextAuth конфиг
```

Алиас импортов: `@/*` -> `./src/*`. Не пиши `../../../`, всегда через `@/`.

## Mobile-first

Aivus full-mobile: и client, и vendor. PO-решение #8 от 2026-02-12 (vendor desktop-only stub) **отменено**.

### Breakpoint

Один: `1023.98/1024 px`. Всё ниже — мобила, выше — desktop. Конкретно:

```typescript
// Frontend/src/styles/breakpoints.ts
BREAKPOINTS.mobile = 1023
BREAKPOINTS.desktop = 1024
MOBILE_MEDIA_QUERY = '(max-width: 1023.98px)'
```

Antd `screenLG=992` не используется как порог — у нас свой.

### useBreakpoint

```typescript
import { useBreakpoint } from '@/hooks/useBreakpoint';
const { isMobile, isDesktop, ready } = useBreakpoint();
```

SSR-safe через `useSyncExternalStore`. Не использовать локальные `useState(matchMedia)`.

### Media queries в `.module.css`

Mobile-first: основной стиль для мобилы, desktop через `@media (min-width: 1024px)`. Можно и наоборот (max-width: 1023.98). Без миксин/SCSS, чистый CSS.

```css
.card {
  padding: 12px;
  font-size: 14px;
}

@media (min-width: 1024px) {
  .card {
    padding: 24px;
  }
}
```

### Touch targets

44 px минимум. В `themeConfig.ts` есть `controlHeightLG=44`. В `AppShell` оборачивай `<ConfigProvider componentSize="large">` при `isMobile` чтобы кнопки и инпуты автоматически выросли до 44.

### iOS Safari input zoom-fix

`Input.inputFontSize=16` в `themeConfig.ts.components.Input`. Если меньше — Safari зумит viewport при фокусе. Не уменьшать.

## AppShell

Единый layout-компонент `@/components/layout/AppShell`. Composition через slots:

```typescript
import { AppShell, useAppShell } from '@/components/layout/AppShell';

<AppShell
  sider={<MySidebar />}           // desktop sider
  drawer={<MyMobileNav />}        // mobile drawer (off-canvas)
  headerLeft={<Logo />}
  headerRight={<Profile />}
  hideSider={isBriefPage}          // hide sider на определённых маршрутах
  footer={<BetaFooter />}
  drawerTheme='dark'               // light | dark, дефолт dark
>
  {children}
</AppShell>
```

Header sticky 70 px (desktop) / 56 px (mobile) через CSS var `--aivus-header-h`. Drawer left, `min(320px, 85vw)`.

Внутри drawer-children используй `useAppShell()` чтобы закрыть drawer при навигации:

```typescript
const { closeDrawer } = useAppShell();
```

## Компоненты — БЕЗ `React.FC` (override глобального CLAUDE.md)

В Aivus компоненты пишутся стрелочными функциями:

```typescript
interface BriefCardProps {
  value: number;
  onChange: (value: number) => void;
}

export const BriefCard = (props: BriefCardProps) => {
  const { token } = theme.useToken();
  return (
    <div className={styles.card} style={{ color: token.colorTextHeading }}>
      {props.value}
    </div>
  );
};
```

- Props интерфейс `XProps` именованный, объявляется **сразу над компонентом**
- Если есть `value` и `onChange` — идут первыми в интерфейсе
- `children: React.ReactNode` типизируй явно
- Один компонент — один файл, имя файла = имя компонента + `.module.css` + `.test.tsx` рядом
- Без сложной деструктуризации в сигнатуре, доставай через `props.x`
- Named exports. Default exports — только для `page.tsx`/`layout.tsx` Next.js

## Стили

### Что куда

- **Цвета, radius, font-size, spacing** — через `theme.useToken()` в TSX, прокидывай в JSX `style={{ color: token.colorText }}`.
- **Верстка** (flex, grid, padding, медиа-запросы) — в `Component.module.css`.
- **Inline `style={{}}`** запрещён, кроме двух случаев:
  1. Прокидка значения из `theme.useToken()`.
  2. Прокидка dynamic CSS variable: `style={{ '--row-bg': bg } as React.CSSProperties}` в TSX, `background: var(--row-bg)` в CSS.

### Запрещённые подходы

- `styled-components` — выпилен. Если видишь `import { styled }` — это легаси, мигрируется.
- `@emotion/*` — никогда.
- Хардкод хексов — все цвета через token или domain CSS vars.

### Запрещённые импорты

Эти компоненты удалены, не использовать:

- `@/components/Modal/Modal` — используй antd `Modal`.
- `@/components/SideModal` — используй antd `Drawer`.
- `@/components/Text` — используй antd `Typography.Text/Title/Paragraph`.
- `@/components/Spinner` — используй `@/components/PageSpinner/PageSpinner` (для fullscreen) или antd `Spin` (inline).

## RTK Query

```typescript
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';

export const briefApi = createApi({
  reducerPath: 'briefApi',
  baseQuery: fetchBaseQuery({ baseUrl: '/api/v1/' }),
  endpoints: builder => ({
    getBriefs: builder.query<Brief[], void>({ query: () => 'briefs/' }),
    createBrief: builder.mutation<Brief, NewBrief>({
      query: body => ({ url: 'briefs/', method: 'POST', body }),
    }),
  }),
});
```

- Файлы в `src/services/client/*Api.ts`
- Mutation и query всегда типизированы: `<TResult, TArg>`
- Регистрируй reducer в `src/store/store.ts`

## Redux slices

```typescript
const vendorSlice = createSlice({
  name: 'vendor',
  initialState,
  reducers: {
    setActiveProject: (state, action: PayloadAction<string>) => {
      state.activeProjectId = action.payload;
    },
  },
});
```

Slices в `src/store/slices/`. `PayloadAction<T>` для типизации экшенов.

## Локализация

Словари — простые TS-объекты:

```typescript
export const EN_LOCALES = {
  ADD_FREELANCERS: 'Add freelancers',
  OPEN_NAVIGATION: 'Open navigation',
};
```

SSR через middleware → header `x-locale` → `await headers()` в layout. На клиенте `getLocale()` читает cookie.

**Не возвращай** `NEXT_PUBLIC_LOCALE` в окружение Docker — locale per-request. См. `Specs/archive/HANDOFF.md`.

Все видимые пользователю строки — через `t('KEY')`. Хардкод запрещён.

## Тесты

### Vitest

- jsdom, файлы рядом с кодом (`Component.test.tsx` рядом с `Component.tsx`)
- `vi.fn()`, `vi.mock('@/services/client/briefApi')`
- `window.matchMedia` и browser APIs мокаются в `src/test/setup.ts`
- Минимум на компонент: рендер без падения + один user-event

### Playwright E2E

- В `Frontend/e2e/`. Project `smoke` (CI, минимальный smoke), `chromium` (полный, локально), `mobile-smoke.spec.ts` (iPhone 13 viewport), `tablet-smoke.spec.ts` (iPad Mini, проверка порога 1024).
- Запуск: `make e2e`, `make e2e-smoke`, `make e2e-ui`.
- Smoke против прода: `SMOKE_TEST_URL=https://go.aivus.co make e2e-smoke`.

## Workflow frontend

- После **любой** правки в `Frontend/` обязательно: kill порт 3000, `rm -rf .next`, `npm run dev` в фоне. Не делать — CSS 404 и сломанный dev server.
- Типы: `npx tsc --noEmit`. **Никогда `npm run build`** — он перезаписывает `.next` и ломает работающий dev server.
- Pre-commit: `npm run typecheck && lint-staged`.
- Pre-push (husky): typecheck + vitest, ~30 сек.
- E2E локально: `make e2e`. Smoke против прода: `make e2e-smoke`.

## MCP для frontend

- **Ant Design** — `antd` MCP, обязателен при работе с UI-компонентами:
  - `mcp__antd__antd_list`, `antd_doc`, `antd_demo`, `antd_token`, `antd_semantic`, `antd_info`, `antd_changelog`.
  - **Когда вызывать**: перед добавлением нового antd-компонента смотри `antd_doc` + `antd_demo`. Перед кастомизацией темы — `antd_token`. Не пиши props по памяти, версия `^5.22.5` могла переименовать что угодно.
- **Figma макеты** — `figma-dev-mode` для дизайн-контекста и переменных. Маппи в antd. Figma Node IDs в MEMORY.md.
- **Manual UI debugging** — `chrome-devtools` (`emulate`, `take_screenshot`, `lighthouse_audit`).
- **E2E** — `playwright` (один сценарий) или `make e2e` (пакет).

## Subagents

В `.claude/agents/` живут два специализированных subagent для фронта:

- `aivus-frontend-architect` — design system, токены, AppShell, общий layout, ревью паттернов. НЕ для per-module миграции.
- `aivus-frontend-feature` — фичи, mobile-first верстка, миграция компонентов, vitest. НЕ для themeConfig/AppShell.

Вызывай через `Agent({subagent_type: 'aivus-frontend-architect'|'aivus-frontend-feature', ...})` для делегирования.

## Анти-паттерны frontend

- `React.FC<Props>` — не наш паттерн, стрелочные функции с типизированными props.
- `styled-components` — выпилен, не возвращать.
- `npm run build` для проверки типов — ломает dev server.
- Импорты `../../../` — используй `@/`.
- Сложная деструктуризация props в сигнатуре `({ a, b, c }: Props)` — называй `props`, доставай внутри.
- Возврат `undefined` из компонента — пусть будет `null`.
- Хардкод текстов вместо словарей локализации.
- Хардкод хексов цветов — через `theme.useToken()` или domain CSS vars.
- Inline `style={{}}` без token/CSS var — антипаттерн.
- `NEXT_PUBLIC_LOCALE` в Docker окружении — locale per-request.
- Импорты из `components/Modal|SideModal|Text|Spinner` — удалены, не существуют.
- Горизонтальный скролл + warning toast как «мобильная адаптация» — нет, использовать `Table.scroll/expandable/responsive` от antd или card-per-row.
