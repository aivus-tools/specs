# Как мы ведём разработку, баги и трекинг

Документ описывает, как мы с агентом двигаемся по работе: где что лежит в ClickUp, как задача проходит путь от идеи до готового кода, и как мы обрабатываем баги. Источник истины по процессу. Видение и роадмап — в `Specs/PRODUCT_VISION.md`.

Всё ведём в ClickUp, workspace VILKA, спейс «Shared with me», только через обёртку `scripts/clickup` (скоуп VILKA enforced). Прямых вызовов API и MCP не делаем.

## Три листа

1. **✏️ Conceptualization** (папка Dev plan). Тут думаем, что и зачем строим. Сюда заходят стадии роадмапа и крупные фичи как концепты. Тут идёт grilling, проработка corner case и PRD. Никакого кода.
2. **🚧 Development** (папка Dev plan). Тут строим. Вертикальные слайсы из PRD, инженерные задачи, тех-долг, staging. Тут пишется код, гоняются тесты, проходит ревью.
3. **Bug Tracking** (папка NEW PM Logic). Тут всё, что сломалось. Баги приходят через Bug Submission Form или заводятся вручную, проходят триаж и фикс.

Рядом есть Marketing & Sales (не наш скоуп) и legacy-борд Brief NEW (не трогаем).

## Поток фичи: концепт → разработка

Статусы в обоих листах одинаковые: `to do` → `in progress` → `in review` → `revisions` → `blocked` → `complete`.

**Conceptualization:**
1. Фича заводится как эпик (Task Type = Feature), статус `to do`.
2. Беру в работу — `in progress`. Прогоняю `grill-with-docs`: владелец продукта меня гриллит, вытаскиваем спорные продуктовые решения и corner case, фиксируем общий язык в `CONTEXT.md` и решения в ADR.
3. Пишу PRD через `to-prd` (problem, solution, user stories, implementation decisions, testing decisions, out of scope). PRD кладётся в тело эпика. Статус `in review` — владелец продукта смотрит.
4. Правки по PRD — `revisions`, потом снова `in review`. Когда PRD принят и понятно, как резать, — `complete`.

**Переход в Development:**
5. По готовому PRD `to-issues` режет работу на вертикальные слайсы (tracer bullets, каждый сквозь все слои, демонстрируемый сам по себе). Каждый слайс создаётся задачей в Development, в описании ссылка на концепт-эпик. Слайсы помечаются AFK (агент может брать сам) или HITL (нужно решение человека).

**Development:**
6. Слайс `to do` (готов к работе) → `in progress` (пишу код, red-green-refactor, держу `tsc --noEmit` и vitest зелёными) → `in review` (PR готов, гоняю `/code-review`, при нужде `/simplify`) → `revisions` (правки по ревью) → `complete` (смержено и проверено). `blocked` если завис на внешнем.
7. Незнакомый кусок кода перед правкой — `zoom-out`, чтобы понять контекст.

## Поток бага

Статусы: `Open` → `triage` → `in progress` → `need info` → `testing` → `cannot reproduce` / `not a bug` → `Closed`.

1. Баг приходит через Bug Submission Form или заводится вручную, статус `Open`.
2. `triage`: оцениваю и заполняю поля — Severity (S1-S4), Source (Customer/Internal), Report Type (Defect/UI Refinement/Outage/Feature), Product Feature, Environment, Reporter. Если данных мало — `need info`. Если не баг или не воспроизводится — `not a bug` / `cannot reproduce`.
3. Подтверждённый баг иду чинить по `bug-fix-protocol`: сначала воспроизвожу, потом пишу падающий регресс-тест, потом фикс. `in progress`.
4. Фикс готов — `testing`. Прошло — `Closed`, репортеру можно сообщить.
5. Если дефект тянет на заметную работу, завожу связанную задачу в Development и линкую через поле Defect Task.

## Кто что делает

- Я (агент) веду задачи в ClickUp через обёртку, пишу код, тесты, PRD, нарезаю слайсы, чиню баги, держу статусы в актуальном виде.
- Владелец продукта — ревьюер: гриллит на этапе концепта, принимает PRD, ревьюит PR и фиксы, расставляет приоритеты.

## Скиллы под этапы

- Conceptualization: `grill-me`, `grill-with-docs`, `to-prd`.
- Development: `to-issues`, `zoom-out`, `/code-review`, `/simplify`.
- Bug Tracking: `bug-fix-protocol`. Триаж (статус `triage`) - действие по листу: оценить баг и заполнить поля, без отдельного скилла.

## Тексты

Содержательные тексты задач, PRD и комментариев пишутся от первого лица голосом владельца продукта, без упоминания конкретных имён. Технические acceptance criteria — обычным языком.
