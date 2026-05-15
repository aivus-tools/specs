---
name: aivus-frontend
description: "Use ALWAYS for frontend work in Aivus: writing or modifying React components, Next.js pages/routes, Redux state, RTK Query endpoints, vitest tests, Playwright E2E, antd UI, styles (CSS modules/styled-components), localization, NextAuth integration. Trigger for any work in /Frontend/ directory. Always invoke aivus-base alongside this skill for shared context. If task also touches backend API contract, also invoke aivus-backend. If task involves AI brief/chat UI, also invoke aivus-ai."
---

# Aivus Frontend — Next.js 15 + React 19 + RTK Query

**Перед началом**: если в этой сессии ещё не загружен `aivus-base` — вызови его через Skill tool сейчас. Базовые правила (тон, workflow, безопасность, MCP, источники истины) живут там, дублировать не буду.

## Стек

- Next.js 15.2.3 App Router
- React 19
- Redux Toolkit + RTK Query
- NextAuth.js
- UI: Ant Design 5 (`antd`, `@ant-design/nextjs-registry`, `@ant-design/v5-patch-for-react-19`) — единственная компонентная либа
- Стили: antd (темы и токены через `ConfigProvider`), CSS Modules и styled-components для точечной кастомизации
- Тесты: Vitest (jsdom) + Playwright

## Структура `Frontend/src/`

```
src/
├── app/        Next.js App Router pages, layouts, route handlers
├── components/ переиспользуемые UI компоненты
├── modules/    фича-модули (briefs, offers, dashboards)
├── services/   RTK Query API endpoints
│   └── client/ *Api.ts файлы
├── store/      Redux store + slices
├── types/      TypeScript типы
├── locales/    en.ts, ru.ts словари
├── hooks/      кастомные хуки
└── auth/       NextAuth конфиг
```

Алиас импортов: `@/*` -> `./src/*`. Не пиши `../../../`, всегда через `@/`.

## Компоненты — БЕЗ `React.FC` (override глобального CLAUDE.md)

В Aivus компоненты пишутся стрелочными функциями без `React.FC`:

```typescript
interface SumCounterProps {
  value: number;
  onChange: (value: number) => void;
}

export const SumCounter = (props: SumCounterProps) => {
  return <div>{props.value}</div>;
};
```

- Props интерфейс `XProps` именованный, объявляется **сразу над компонентом**
- Если есть `value` и `onChange` — идут первыми в интерфейсе
- `children: React.ReactNode` типизируй явно
- Один компонент — один файл, имя файла = имя компонента (`SumCounter.tsx`)
- Стили в `SumCounter.module.css` рядом
- Без сложной деструктуризации в сигнатуре, доставай поля внутри через `props.x`

## RTK Query

API endpoint:

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
import { createSlice, PayloadAction } from '@reduxjs/toolkit';

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
  ACCOUNT_CREATION_INFO: 'Account creation info',
};
```

SSR через middleware -> header `x-locale` -> `await headers()` в layout. На клиенте `getLocale()` читает cookie.

**Не возвращай** `NEXT_PUBLIC_LOCALE` в окружение Docker — его убрали, чтобы locale работал per-request. См. `HANDOFF.md`.

## Тесты

- Vitest, jsdom, файлы рядом с кодом (`SumCounter.test.tsx` рядом с `SumCounter.tsx`)
- `vi.fn()` для функций-моков, `vi.mock('@/services/client/briefApi')` для модулей
- `window.matchMedia` и другие browser APIs мокаем в `src/test/setup.ts`
- E2E: 20+ Playwright тестов в `Frontend/e2e/`, разделены на `smoke` (CI) и `chromium` (локально)

## Workflow frontend

- После **любой** правки в `Frontend/` обязательно: kill порт 3000, `rm -rf .next`, `npm run dev` в фоне. Не делать — будут CSS 404 и сломанный dev server
- Типы: `npx tsc --noEmit`. **Никогда `npm run build`** — он перезаписывает `.next` и ломает работающий dev server
- Pre-commit: `npm run typecheck && lint-staged`
- Pre-push (husky): typecheck + 319 vitest тестов, ~30 сек
- E2E локально: `make e2e`. Smoke против прода: `make e2e-smoke`

## MCP для frontend

- **Ant Design** — `antd` MCP, обязателен при работе с UI-компонентами:
  - `mcp__antd__antd_list` — список доступных компонентов antd
  - `mcp__antd__antd_doc` — документация по компоненту (props, API)
  - `mcp__antd__antd_demo` — рабочие примеры использования
  - `mcp__antd__antd_token` — design tokens темы (цвета, отступы, типографика)
  - `mcp__antd__antd_semantic` — семантические токены и классы
  - `mcp__antd__antd_info` — мета-инфо (версия, ссылки)
  - `mcp__antd__antd_changelog` — changelog при апгрейде версии
  - **Когда вызывать**: перед добавлением нового antd-компонента посмотри `antd_doc` + `antd_demo`, чтобы не выдумывать API из головы. Перед кастомизацией темы — `antd_token`. Не пиши props по памяти, версия `^5.22.5` могла переименовать что угодно.
- **Figma макеты** — `figma-dev-mode` для дизайн-контекста, переменных и токенов. Маппить вручную в antd-компоненты. Список Figma Node IDs всех экранов (Vendor Dashboard, Templates, Rates, Brief form, Comparison и т.д.) — в MEMORY.md
- **Manual UI debugging** — `chrome-devtools` (console, network, perf trace)
- **E2E** — `playwright` (один сценарий) или `make e2e` (пакет)

## Анти-паттерны frontend

- `React.FC<Props>` — не наш паттерн, стрелочные функции с типизированными props
- `npm run build` для проверки типов — ломает dev server
- Импорты `../../../` — используй `@/`
- Сложная деструктуризация props в сигнатуре `({ a, b, c, ...rest }: Props)` — называй `props`, доставай внутри
- Возврат `undefined` из компонента — пусть будет `null`
- Хардкод текстов вместо словарей локализации
- `NEXT_PUBLIC_LOCALE` в Docker окружении — locale per-request
