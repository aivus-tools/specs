# Issue tracker: ClickUp (workspace VILKA only)

Задачи Aivus ведутся в ClickUp, workspace **VILKA** (`9012361587`), спейс «Shared with me». Доступ только через обёртку `scripts/clickup` (исходник `Specs/scripts/clickup.py`). Обёртка захардкожена на VILKA и отказывает на всём вне этого workspace. Прямые вызовы ClickUp API/MCP не использовать.

Полный флоу разработки, багов и трекинга описан в `Specs/DEV_PROCESS.md` — это источник истины по процессу.

## Листы (три рабочих + два служебных)

| Имя в обёртке      | Лист                  | Назначение                                              |
| ------------------ | --------------------- | ------------------------------------------------------- |
| `conceptualization`| ✏️ Conceptualization  | Продуктовая проработка: концепты стадий, grilling, PRD  |
| `development`      | 🚧 Development        | Реализация: вертикальные слайсы, тех-долг, staging      |
| `bugs`             | Bug Tracking          | Баги: форма приёма, триаж, фикс                         |
| `marketing`        | 📈 Marketing & Sales  | Не наш скоуп, read-only                                 |
| `brief`            | Brief NEW             | Legacy-борд, не трогаем                                  |

Дефолтный лист обёртки — `development`. Все команды берут `--list <имя>`.

## Статусы (разные у Dev plan и Bug Tracking)

- **Conceptualization / Development**: `to do` → `in progress` → `in review` → `revisions` → `blocked` → `complete`.
- **Bug Tracking**: `Open` → `triage` → `in progress` → `need info` → `testing` → `cannot reproduce` → `not a bug` → `Closed`.

Лейблов нет, состояние triage кодируется статусом (см. `triage-labels.md`).

## Конвенции

- **Эпик** — родительская задача в листе, Task Type = `Feature` (или `Improvement` для тех-долга). Декомпозиция — субтаски (`create-task --list X --parent <id>`). Субтаски живут в том же листе, что и родитель.
- **Task Type** (custom field, общий для Dev plan): `Feature`, `Improvement`, `Bug`, `Marketing`.
- **Связь concept ↔ dev**: концепт-задача живёт в `conceptualization`; когда PRD готов, `to-issues` создаёт слайсы в `development`. Ссылку на родительский концепт кладём текстом в описание слайса (ClickUp-таски в разных листах не делаются субтасками друг друга).
- **Приоритет**: `urgent` / `high` / `normal` / `low`.

## Поток по скиллам

- `conceptualization`: `grill-me`, `grill-with-docs` (corner cases, CONTEXT.md, ADR), `to-prd` (PRD как эпик).
- `development`: `to-issues` (нарезка на слайсы), `tdd`, `zoom-out`, `/code-review`, `/simplify`.
- `bugs`: `triage`, `diagnose`, `bug-fix-protocol`.

## Команды обёртки

- `scripts/clickup lists` — карта листов и статусов.
- `scripts/clickup list-tasks --list X [--status S] [--subtasks]`.
- `scripts/clickup get-task <id>`.
- `scripts/clickup create-task --list X --name N [--desc MD] [--status S] [--type T] [--priority P] [--parent <id>]`.
- `scripts/clickup update-task <id> [--name] [--desc] [--status] [--priority]`.
- `scripts/clickup set-type <id> --type T`.
- `scripts/clickup set-field <id> --field-id <fid> --value <v> [--json]` — для bug-полей (Severity, Report Type и т.п.).
- `scripts/clickup comment <id> --text "..."`.
- `scripts/clickup delete-task <id>`.
- `scripts/clickup list-fields --list X` — кастомные поля листа с id и опциями.
- Доки: `create-page`/`update-page`/`get-page`/`list-pages` (`--content-file` для markdown из файла).

## Bug Tracking — поля (id берём через `list-fields --list bugs`)

Report Type (🚨 Defect / 🎨 UI Refinement / 🔌 Outage / 💡 Feature), Source (Customer / Internal), Severity (S1-S4), Product Feature (Core Product, Inbox, Dashboards, Integrations, Performance, Login, Search и др.), Environment (🌐 Web / 📲 Mobile / 💻 Desktop / 🚩 All / 💭 Other), Reporter, Defect Task (url), Confirmed? (checkbox). Баги приходят через Bug Submission Form (view `8cjvebk-4132`).

## Когда скилл говорит «publish to the issue tracker»

PRD — эпик (parent task) в `conceptualization` с телом в `--desc`. Нарезка `to-issues` — субтаски в `development` через `--parent`, в порядке зависимостей (блокеры первыми). Баг — задача в `bugs` со статусом `Open` и заполненными полями.

## Тексты

Содержательные тексты (названия, описания, комментарии, PRD, user stories) пишутся от первого лица голосом владельца продукта (Илья), по стилю из корневого CLAUDE.md. Технические acceptance criteria — обычным языком.
