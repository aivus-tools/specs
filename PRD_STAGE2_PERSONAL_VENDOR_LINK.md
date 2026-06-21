# PRD: Stage 2 — Personal Vendor Link (white-label lead capture)

## Краткое саммари (для согласования)

Раздел для быстрого ознакомления, без погружения в технику. Дальше по документу — детали.

### Суть

Даём каждому вендору личную брендированную ссылку на форму брифа вида `go.aivus.co/brief/<имя>`. Вендор кладёт её на свой сайт, шлёт клиентам в переписке или встраивает прямо в страницу как виджет. Клиент открывает ссылку, видит логотип и название агентства (не наш бренд), проходит короткий диалог с AI-продюсером, перед отправкой видит и при необходимости правит финальный бриф, и одной кнопкой отправляет его. Бриф сразу оказывается у вендора в кабинете как проект-лид. Клиенту не нужно заранее регистрироваться: после отправки ему на почту приходит письмо с двумя действиями — сразу скачать PDF или зарегистрироваться с этим email, чтобы бриф сохранился в кабинете со всеми функциями.

### Зачем это нужно

Вендор собирает заявки под собственным брендом и перестаёт терять лидов в почте и мессенджерах. Это первый кирпич большой картины: дальше система будет вести всю воронку — от заявки до сметы. Поэтому уже сейчас мы аккуратно фиксируем, откуда пришёл каждый лид и какому вендору он принадлежит.

### Как это выглядит для вендора

На главной кабинета сразу видна его ссылка с кнопками «скопировать», «посмотреть» и «встроить на сайт», рядом — настройка брендинга (логотип и название берём из профиля). Ниже — список входящих лидов. Каждый лид помечен: на какой он стадии (ещё заполняется клиентом или уже отправлен) и есть ли по нему контактный email. Так вендор сразу видит, кто в процессе, а с кем уже можно связаться. Дополнительно вендор может подключить форму со своего сайта через персональный ключ — заявки с неё тоже падают ему в кабинет.

### Как это выглядит для клиента

Клиент-новичок (без аккаунта) проходит диалог, перед отправкой обязательно видит финальный текст брифа и может править его прямо там — напрямую и через чат с AI («сделай бюджет гибким»). У анонима это новый экран (своего вью документа сегодня нет, добавляем его, переиспользуя существующий редактор). Если у клиента уже есть аккаунт — в шапке есть вход; после логина он работает с брифом в полном существующем редакторе и правит его как угодно. Эта функциональность уже работает у реальных пользователей, мы её не меняем. После логина клиент может либо составить новый бриф, либо выбрать ранее готовый и отправить вендору в один клик. На брендированной странице у залогиненного скрыты только скачивание PDF, share и карточки других вендоров — само редактирование остаётся.

### Ключевые продуктовые решения

- Лид появляется у вендора сразу, как только клиент начал заполнять бриф, даже если ещё не закончил, — недозаполненный лид тоже полезен. Стадия и наличие email всегда видны.
- Никаких копий брифа: вендор видит тот же бриф по прямой связи, только на чтение. Редактирует бриф всегда клиент.
- Клиента не заставляем регистрироваться до отправки, чтобы не терять заявки на ровном месте.

### Что предусмотрели на краевых случаях

- Клиент бросил заполнение на середине или закрыл вкладку — лид всё равно виден вендору с пометкой «в процессе», без отправки. Клиент может вернуться по сохранённой ссылке и дожать.
- Клиент ввёл при отправке email, на который уже есть аккаунт, — мы не плодим дубль, а зовём его войти; бриф привяжется к существующему аккаунту. Лид к вендору при этом уходит в любом случае.
- Один и тот же бриф нельзя отправить одному вендору дважды — после отправки кнопка пропадает. Тот же бриф другому вендору отправить можно.
- Email с опечаткой — письмо клиенту не дойдёт, но лид у вендора остаётся (мы намеренно не теряем заявку; верификация и фильтрация мусора — следующий этап).
- Вендор поменял свою ссылку — старая перестаёт работать (для MVP осознанно, без переадресации). Предупреждаем об этом.
- Встраивание на сайт (embed) на старте — только анонимный путь до отправки; вход в аккаунт внутри встроенного окна открывается отдельной вкладкой (ограничение браузеров на cookies в iframe).
- Защита от мусора и ботов: ограничения по частоте на открытие ссылки и отправку; явный спам админ может удалить вручную.
- Вендора удалили из системы — клиент видит мягкое сообщение «агентство больше не принимает брифы», его бриф не пропадает.

### Объём работ

Около двух десятков задач разработки, разбитых по слоям и зависимостям, отдельными карточками. Сначала фундамент (ссылка, брендинг, связь лида с вендором), затем отправка и письма, приём на стороне вендора с пометками лидов, в конце — встраивание на сайт и подключение по ключу.

---

## 1. Проблема и цель

Бриф сейчас живёт только внутри клиентского кабинета: клиент сам пришёл, сам зарегался, сам составил, сам решил с кем шарить. Вендор — пассивный получатель. Это ломает главный go-to-market: вендор хочет приводить своих клиентов, через свой канал, под своим брендом, и получать готовые брифы себе в кабинет без танцев с регистрацией клиента.

Stage 2 закрывает ровно это. У каждого вендора — персональная брендированная ссылка `go.aivus.co/brief/<slug>`. Он кладёт её на сайт, шлёт в переписке, встраивает embed-виджет, собирает лидов вебхуком со своим ключом. Клиент проходит AI-бриф под брендингом агентства, жмёт Send — заполненный бриф появляется в кабинете вендора как обычный проект.

Зачем бизнесу:
- white-label убирает трение «почему я отправляю клиента в какой-то Aivus» — клиент видит бренд агентства;
- бриф автоматически атрибутируется вендору;
- это фундамент под Stage 3 (inbox/mini-CRM лидов) и Stage 4 (автогенерация оффера из брифа). Поэтому в модель сразу закладываем `source` и vendor-привязку как seam.

Связь сущностей (база этапа): **Client → Brief → Project (вендора) → Offers**. Бриф создаёт клиент/аноним. Когда бриф отправлен вендору, у вендора создаётся проект, к которому привязан этот же бриф. Никаких копий брифа — только прямые связи через FK. Вендор бриф не редактирует, только читает.

Что переиспользуем без изменений: анонимный chat/token-стек (`anonymous_token`, `X-Brief-Token`, `_get_brief_for_token`), публичные start/chat/status/attachments/transcribe/detail эндпоинты, claim для клиентской стороны, `finalize_brief_task`/`generate_final_documents`/`brief_pdf`, localStorage/`pendingBrief.ts`, `BriefChatPanel`.

Что строим с нуля: slug-резолв и draft-by-slug, редактируемый документ анониму (pre-Send, токенные GET+PATCH поверх существующего механизма правки), Send-флоу (async chain finalize→перевод Project в RFP→BriefShare→emails), привязку Project к брифу в обход vendor-guard, vendor-read PDF, email-path без User-контекста с PDF-вложением, vendor-нотификацию, per-vendor webhook-ключ, CSP для `/brief/*`, доработку `_create_inbound_brief`. Публичную ссылку/PDF в письме НЕ изобретаем — переиспользуем существующий `BriefShare`.

Инварианты этапа (важно: не плодим новых связей, используем существующую модель):
1. Связь «бриф у вендора» = существующий `Project(vendor FK, brief FK, client FK, status)`. Новых FK на Brief не добавляем. `Project(vendor, brief)` создаётся СРАЗУ при старте брифа на странице вендора со `status=DRAFT` — лид «в процессе заполнения», уже полезен вендору. На Send → `status=RFP` (отправленный лид). Стадию лида показываем через `Project.status`, а наличие контакта — через `Brief.contact_email`. Без копий брифа.
2. Единственное новое поле — скаляр `source` на Brief (`direct`/`personal_link`/`webhook`/`wix`) для аналитики и Stage 3. Это атрибут происхождения, не связь. Стадия лида и «есть ли email» берутся из существующих `Project.status` / `Brief.conversation_status` / `Brief.contact_email` — новых полей не нужно.
3. Один бриф может иметь проекты у разных вендоров (`brief.projects`) — существующий FK это уже позволяет.
4. Заложен seam под Stage 3 lead-модель (через `source` + Project).
5. Hide-not-delete: брифы/проекты вендора физически не удаляем (кроме админки), чтобы Stage 4 не спотыкался.

## 2. Роли и персоны

| Роль | Кто это | Что делает в Stage 2 |
|---|---|---|
| Vendor | агентство/продакшн, владелец кабинета | задаёт slug, видит блок ссылки на главной, копирует/превьюит/embed-ит, получает брифы как проекты, генерит webhook-ключ. Только читает брифы. |
| Аноним-клиент | потенциальный заказчик, без сессии | открывает `/brief/<slug>`, проходит AI-бриф, жмёт Send, получает письмо со ссылкой, регится |
| Залогиненный клиент | заказчик с аккаунтом | логинится в хедере, стартует новый бриф либо отправляет ранее готовый |
| AI-агент | Brief AI v3 | ведёт диалог, в white-label режиме не толкает к регистрации, мягко ведёт к Send |

Вендор бриф не создаёт. Создаёт всегда клиент/аноним, вендор принимает.

## 3. Информационная архитектура

### Публичный (white-label) флоу — новые роуты

```
/brief/[slug]                старт-экран с брендингом вендора (аноним) + хедер-логин
/brief/[slug]/[briefId]      редактор анон-брифа (token в query/localStorage)
/brief/[slug]/success        success-экран после Send
```

Брендированный аналог `/public-brief` (`src/app/public-brief/`). Под капотом тот же анонимный стек:
- инициализация через `getPublicBriefBySlug({ slug })` — резолвит вендора и брендинг с проверкой `deleted_at IS NULL`;
- последующие запросы (`start`, `chat`, `status`, `attachments`, `transcribe`, `detail`) — по существующим `X-Brief-Token` эндпоинтам без изменений;
- для АНОНИМА финальный документ показываем РЕДАКТИРУЕМЫМ через токенные эндпоинты `public/.../final-documents` (GET+PATCH по `X-Brief-Token`) — переиспользуем существующий механизм правки документа (`getBriefAiFinalDocuments`/`updateBriefAiFinalDocument`), только token-версия; у анонима своего вью документа сегодня нет — это добавление;
- для ЗАЛОГИНЕННОГО клиента используем существующий полный редактор (`AuthenticatedBriefEditor`/`BriefFinalPackage`) без изменений: он правит бриф как угодно. White-label лишь скрывает Download/Share/PreVendors/vendor_email на брендированной странице, редактирование остаётся;
- PDF/Share/PreVendors/vendor_email скрыты (white-label gate, §5).

Существующий `/public-brief` остаётся как есть. Не трогаем.

### Кабинет вендора — ссылка на главной

Целевое действие вендора — получить и распространить ссылку, поэтому блок ставим прямо на главную дашборда, на виду. Дашборд-хоум (`@vendor/dashboard/page.tsx`) сверху вниз:

```
[ PersonalLinkPanel ]   твоя ссылка: URL + Copy + Preview + Embed
[ Branding hint ]       лого и название (тянутся из профиля) + ссылка в Settings
[ ProjectList ]         список твоих проектов с брифами от лидов (как сейчас)
```

Slug, lead-notification-email и webhook-ключ настраиваются в `VendorSettingsSection`, рядом с брендингом. Лого и название берём из `VendorSettings`.

### Приём брифа на стороне вендора

Бриф приходит как обычный `Project` в `ProjectList`. Вендор открывает деталь, качает PDF (через новый vendor-read эндпоинт, §6), генерит share. Атрибуция (`source=personal_link`) в UI пока не светится, лежит под Stage 3.

## 4. End-to-end юзерфлоу

### (а) Вендор настраивает ссылку

1. Settings → поле **Brief link** со slug. Дефолтный slug предлагается автоматически при первом заходе: дешёвая LLM-модель генерит релевантный компании вариант (по `company_name`/`agency_name`), с fallback на `slugify(name)` и `vendor-<short-uuid>`.
2. Редактирование slug. Валидация на лету: `^[a-z0-9-]{3,40}$`, не reserved, уникален. На коллизии — inline «This link is taken». Сервер при сохранении ловит `IntegrityError` → 409 (превентивный GET не панацея против гонки).
3. **Lead notification email** (дефолт — owner.email). Одно поле.
4. На главной дашборда **PersonalLinkPanel**: `go.aivus.co/brief/<slug>`, **Copy**, **Preview** (`/brief/<slug>` в новой вкладке), **Embed** (modal с iframe-сниппетом).
5. Corner cases:
   - slug ещё не задан → панель показывает CTA «Set up your brief link» в Settings, Copy/Preview задизейблены;
   - смена slug → старый сразу 404, редиректов нет (осознанно). Предупреждаем тултипом «changing the link breaks old copies and embeds».

### (б) Аноним-клиент проходит и отправляет

1. Открывает `/brief/<slug>`. Фронт зовёт `getPublicBriefBySlug({ slug })` → `{ valid, vendorName, vendorLogoUrl, slug }`.
2. **Старт-экран** с брендингом: лого + «Brief for {vendorName}» + «Start brief». Невалидный/soft-deleted slug → 404 «Link not found».
3. Start → `POST .../by-slug/<slug>/drafts` создаёт анонимный draft (`source=personal_link`) И сразу `Project(vendor, brief, status=DRAFT)` (get_or_create, в обход guard) — вендор сразу видит лид «в процессе заполнения». Возвращает `briefId` + `token`, кладём в localStorage + cookie `aivus_pending_brief`.
4. Редирект на `/brief/<slug>/<briefId>?token=...`. Дальше переиспользуем `AnonymousBriefEditor` (чат по `X-Brief-Token`).
5. Лимиты анона как сейчас: 50 сообщений, 3 attachment, rate-limit.
6. AI доводит до `ready_to_finalize`. В white-label режиме промпт не толкает к регистрации (S2-21). Перед отправкой клиент **обязательно видит финальный текст брифа** и может править его прямо там — **напрямую** (токенный PATCH) и/или через чат с AI («подправь бюджет, сделай гибким»). Чат видит ручные правки (существующий механизм передачи documentHtml). Кнопки PDF/Share скрыты до Send.
7. **PDF/Share/PreVendors/vendor_email скрыты**. Вместо них primary CTA **«Send brief»**.
8. Send активен только при `conversation_status ∈ {ready_to_finalize, finalized}`. Клик → модалка с полем **Email** (required).
9. Backend (Send): async chain `finalize_brief_task (если нужно) → mark_project_sent_task → send_emails_task`. Проект уже существует (создан на старте) — chain переводит его `status DRAFT→RFP` после `COMPLETED`, проставляет имя/`client` и шлёт письма. Возвращает `{ ok, finalizingTaskId }` для поллинга.
10. **Success-экран** по завершению поллинга: «Brief sent to {vendorName}! Чтобы скачать PDF — ссылка в письме». PDF тут не даём.
11. Corner cases:
    - бриф не дошёл до `ready_to_finalize` → Send disabled (лид всё равно виден вендору как «в процессе заполнения»);
    - закрыл вкладку до Send → бриф и его Project остаются в `status=DRAFT`, вендор видит лид «в процессе» (без отправки). Cookie 1h позволяет вернуться и дожать;
    - дубль Send (двойной клик / возврат / Celery-ретрай) → переход в RFP идемпотентен (уже RFP → no-op), проект один (get_or_create на старте).

### (в) Account matching при уже зарегистрированном email

1. Vendor-лид создаётся на Send **независимо** от того, есть ли у email аккаунт. Это разводит два процесса: лид у вендора (всегда) и клиентский доступ к своему брифу (через claim).
2. Детект существующего email и развилку письма делаем в async send_emails_task — ответ Send одинаков за константное время (анти-enumeration).
3. Письмо клиенту: (а) primary CTA «Зарегистрируйся с этим email — сохранишь бриф в кабинете со всеми функциями»; (б) публичная ссылка на бриф — тот же `BriefShare`, которым клиент шарит бриф сейчас (`/shared-brief/<token>`: просмотр + скачивание PDF); (в) PDF приложен **вложением** в письмо. Если email уже зарегистрирован → вместо CTA регистрации «Войди, чтобы открыть свой бриф». PDF/ссылка публичны — лид у вендора уже есть, держать его в заложниках незачем. Аккаунт заранее НЕ создаём (см. §12 п.15).
4. Ссылка из письма ведёт: `/app/brief/claim/{briefId}?token=...` → нет сессии → регистрация/логин с предзаполненным и **залоченным** email (тем, что ввели на Send) → задаёт пароль или Google one-tap → после auth claim привязывает бриф к Client-профилю (token переживает redirect). Email менять нельзя — это верификация владения почтой. Если Client-профиля нет — создаём лениво на claim, **группу не меняем**.
5. Corner cases:
   - email принадлежит существующему vendor-аккаунту → см. §12 п.3 (для MVP: шлём login-письмо, лид у вендора есть; принудительно роль не переключаем);
   - email-typo → клиент не получит ссылку, лид у вендора остаётся (unverified by design, §8). Resend — out of scope.

### (г) Залогиненный клиент — новый бриф или выбор готового

1. На `/brief/<slug>` в хедере **«Already made a brief? Log in»** (или профиль, если сессия есть). Логин — редирект на `/auth/login?next=/brief/<slug>`.
2. После логина проверяем готовые брифы клиента.
3. Нет готовых → ведём как нового, от лица залогиненного. На Send — проект вендору + письмо вендору, email/регистрацию не спрашиваем.
4. Есть готовые → **экран выбора**: «Start new brief with AI» или список готовых.
5. Выбрал готовый → пропускаем диалог, открываем бриф в полном существующем редакторе (клиент правит как обычно) + «Готовы отправить {vendorName}?» + **Send**.
6. Send → у вендора создаётся проект, привязанный к этому же брифу (без копии), письмо вендору. Клиенту письмо не шлём (он и так в кабинете).
7. **Нет повторной отправки одного брифа одному вендору**: если для пары `(brief, vendor)` проект уже существует, кнопку Send не показываем (бриф уже у вендора). Тот же бриф другому вендору отправить можно — это отдельный проект у другого вендора.
8. Corner cases:
   - стартовал новый AI-диалог под slug, не дожал → обычный draft в его кабинете, к вендору не уходит до Send;
   - сессия истекла → откатываем на хедер-логин.

### (д) Приём на стороне вендора

1. Проект уже создан при старте брифа (`status=DRAFT`) и виден вендору сразу как лид «в процессе заполнения». На Send chain переводит его в `status=RFP`, проставляет имя и `client=brief.client`. Для залогиненного выбора готового брифа (он не стартовал на странице вендора) проект создаётся на Send сразу в `RFP` (get_or_create).
2. Проект появляется в `ProjectList` на главной с момента старта. Маркеры на карточке: стадия лида (`status=DRAFT` → «In progress / filling», `RFP` → «New lead») и наличие контакта («Email: yes/no» из `brief.contact_email`). Вендор сразу видит, какие лиды ещё заполняются и по каким уже есть email.
3. Вендору — email «New brief via your personal link» без PDF, ссылка на проект. Простой шаблон `vendor_lead_{en,ru}`.
4. Вендор внутри: деталь → PDF через новый vendor-read эндпоинт (авторизация по `project.vendor == request vendor`) → share → стандартный флоу.
5. Notification на `lead_notification_email` (дефолт owner.email).
6. Corner cases:
   - вендор soft-deleted к моменту Send → проект не создаём, клиенту мягкая ошибка «This agency is no longer accepting briefs»;
   - notification-email невалиден → письмо ретраится Celery, проект создан.

### (е) Лид через вебхук с ключом вендора

1. Персональный webhook-ключ генерится/ротейтится в Settings.
2. Внешняя форма шлёт `POST /service/public/briefs/ai/from-webhook` с `X-Aivus-Webhook-Key: <vendor_key>` (отдельный заголовок от глобального `X-Aivus-Webhook-Secret` Wix).
3. Backend: `_verify_vendor_webhook_key` (hmac.compare_digest) → vendor → `_create_inbound_brief(..., vendor, source="webhook")`. Функцию дорабатываем, чтобы писать `source` на Brief и сразу создавать `Project(vendor, brief, status=RFP)`. Заодно ретрофитим legacy-wix на `source="wix"` (у глобального Wix вендора нет → проект не создаём, как сейчас).
4. MVP: создаём бриф + проект вендору + notification, как при Send.
5. Лимиты файлов/длины — переиспользуем анон-лимиты. Rate-limit `50/h` по vendor_id (не по строке ключа).
6. Corner cases:
   - невалидный/ревокнутый ключ → 401, ничего не создаём;
   - ротация ломает старый ключ мгновенно (OneToOne, без грейса) — предупреждаем popconfirm;
   - ключ не в логи.

### (ж) Embed на сайт

1. **Embed** открывает modal со сниппетом:
   ```html
   <iframe src="https://go.aivus.co/brief/<slug>?embed=1" width="100%" height="700" frameborder="0"></iframe>
   ```
2. `?embed=1` включает компактный хром.
3. CSP: правка в `Frontend/src/middleware.ts` — `/brief` в public-route allowlist; для `/brief/*?embed=1` CSP с `frame-ancestors *`, остальной домен — текущий жёсткий allowlist. Clickjacking-риск зафиксирован.
4. Corner cases:
   - third-party cookie в iframe режется → embed только анонимный путь, localStorage + query-token;
   - логин/claim в iframe не работают → хедер-логин в embed открывает `_blank`;
   - mobile в 700px-iframe не вылизываем.

## 5. UX-решения

Mobile-first, antd 5, `componentSize="large"` на мобиле, touch 44px, брейкпоинт 1023.98/1024.

### Старт-экран `/brief/<slug>` (аноним)
`antd Layout` + центрированный `Card` (на мобиле full-width). Брендинг: `Avatar`/`img` с `vendorLogoUrl` (fallback — инициалы), `Typography.Title level={3}` «Brief for {vendorName}», подзаголовок, primary `Button` «Start brief». Хедер: «Already made a brief? Log in» (нет сессии) либо профиль. Locale: Accept-Language, дефолт en.

### Редактор брифа (анон, white-label)
Это про АНОНИМНЫЙ white-label редактор. Двухпанельный на desktop (слева документ, справа чат), на мобиле — табы (Brief / Chat). Документ **редактируемый**: переиспользуем существующий редактируемый компонент документа (как в авторизованном редакторе) на токенных GET+PATCH, без PreVendors/PickVendorButton/Share/Download/vendor_email. Клиент видит финальный текст и правит его напрямую и/или через чат; чат видит ручные правки.

Для ЗАЛОГИНЕННОГО клиента на брендированной странице — существующий полный редактор (`AuthenticatedBriefEditor`/`BriefFinalPackage`), правит как обычно, поведение не трогаем. White-label = тот же редактор с флагом, который прячет Download PDF, Share, вкладку vendor_email, PickVendorButton и PreVendor-блок (на странице вендора A нельзя показывать карточки B/C). Редактирование остаётся.

### Send-флоу
**«Send brief»** активна только при `conversation_status ∈ {ready_to_finalize, finalized}`. Клик → `antd Modal` «Send to {vendorName}»: аноним — поле Email (required); залогиненный — без email. На submit — лоадер, поллинг `finalizingTaskId`, затем редирект на success.

Текст AI в конце (device-aware):
- готовность: «Всё готово, давайте проверим бриф. Документ — слева на компьютере или во вкладке Brief на телефоне. Посмотрите и поправьте через чат, если надо.» (EN: «All set, let's review your brief. The document is on the left on desktop, or in the Brief tab on mobile. Tell me here if anything needs a tweak.»)
- призыв: «Если всё верно, нажмите Отправить бриф. На почту придёт ссылка, чтобы не потерять его и скачать.» (EN: «If it looks right, hit Send brief. We'll email you a link so you don't lose it and can download it.»)

### Success-экран
`Result status="success"`: аноним — «Check your inbox»; залогиненный — «Your brief is now with {vendorName}» + «Go to my briefs». PDF для анона не показываем.

### Дашборд-хоум вендора
Сверху **PersonalLinkPanel** (`Card` «Your brief link»: URL `Typography.Text code ellipsis` + Copy + Preview + Embed; empty state без slug — CTA в Settings). Под ним короткий hint по брендингу со ссылкой в Settings. Ниже — существующий `ProjectList` (проекты с брифами от лидов). Embed-modal: `Input.TextArea readOnly` + Copy.

### Settings
**Brief link slug**: `Input addonBefore="go.aivus.co/brief/"`, debounce-валидация, inline-коллизия, кнопка «Suggest» (LLM-предложение). **Lead notification email**: `Input type="email"`. **Webhook key**: `Input.Password readOnly` + «Regenerate» (popconfirm «old key stops working») + Copy.

### Выбор готового брифа (залогиненный)
`Modal`/экран: `Card` «Start new brief with AI» + список готовых (брифы, уже отправленные этому вендору, помечены и без Send). Выбор → бриф открывается в полном редакторе (можно править) + Send.

## 6. Модель данных и API

### Backend модели

**VendorSettings** (`users/models.py:283`) — рядом с брендингом:
- `+ slug = SlugField(max_length=40, unique=True, db_index=True, null=True, blank=True)`.
- `+ lead_notification_email = EmailField(blank=True, default="")` — не `notification_email` (конфликт с `UserSettings.notification_email` BooleanField).
- Дефолт slug: LLM-предложение при первом GET settings, fallback `slugify(name)` → `vendor-<short-uuid>`. Reserved-проверка. Детерминированный суффикс при коллизии.

**Brief** (`projects/models.py:35`)
- `+ source = CharField(choices=BriefSource.choices, default="direct", db_index=True)` — `direct | personal_link | webhook | wix`. Единственное новое поле, скаляр для аналитики. НЕ добавляем `target_vendor`/`sent_to_vendor_at` — это дублировало бы существующую связь `Project(vendor, brief)` и факт её существования.

**Project** (`projects/models.py:81`) — без новых полей. Используем как есть: `vendor` (PROTECT), `brief` (SET_NULL), `client` (SET_NULL), `status` (ProjectStatus). Бриф привязывается напрямую через `Project.brief`, без копий; один бриф может иметь проекты у разных вендоров (`brief.projects`). Отправленный лид = `Project(vendor, brief, status=RFP)`. Атрибуция = `Project.vendor`.

**VendorWebhookKey** (новая, `users/models.py`)
- `id: UUID PK`, `vendor: OneToOneField(Vendor, CASCADE, related_name="webhook_key")`, `key: CharField(unique=True, db_index=True)` = `secrets.token_urlsafe(32)`, `is_active`, `created_at, rotated_at, revoked_at`. Rotate = новый key + rotated_at (старый мёртв сразу).

**BriefSource** enum — в `core/enums.py`.

### Backend эндпоинты

**Slug-резолв:**
- `GET /service/public/briefs/ai/by-slug/<slug>` → `{ valid, vendorName, vendorLogoUrl, slug }`. 404 если не найден / vendor soft-deleted (фильтр `deleted_at` вручную). Rate-limit `60/h` по IP. Только публичный брендинг.
- `POST /service/public/briefs/ai/by-slug/<slug>/drafts` → draft (`source=personal_link`) + `get_or_create Project(vendor, brief, status=DRAFT)` в обход guard. → `{ briefId, token }`.
- `GET /service/vendor/settings/slug/suggest` → LLM-предложение slug по брендингу (дешёвая модель).

**Send (новый, ключевой, асинхронный):**
- `POST /service/public/briefs/ai/<briefId>/send` (X-Brief-Token, аноним) и `POST /service/client/briefs/ai/<briefId>/send` (auth). body: `{ email?, idempotencyKey? }`.
- Вендор резолвится из slug (анон/branded — slug в теле/контексте запроса) или из ключа (webhook). body: `{ email?, slug?, idempotencyKey? }`.
- Вью: проверить статус, резолв vendor по slug + `deleted_at IS NULL`, проверить что Project `(brief, vendor)` ещё нет, выставить `pending_task_id`, диспатчить chain через `transaction.on_commit`, вернуть `{ ok, finalizingTaskId }`.
- chain: `finalize_brief_task (если нужно) → mark_project_sent_task → send_emails_task`, каждый шаг идемпотентен.
- `mark_project_sent_task`: находит Project `(brief, vendor)` (создан на старте; для auth-выбора готового — get_or_create), ставит `status=RFP`, имя (`brief.title`/fallback), `client=brief.client`. Идемпотентно (уже RFP → no-op). «Нет повторной отправки» — Send скрыт/отклонён если `status >= RFP`.
- `serialize_project` расширяем: `briefConversationStatus` и `hasContactEmail` (из `brief.contact_email`) — для маркеров «в процессе заполнения» и «email есть/нет» в списке вендора.

**Документы клиента — переиспользуем существующий BriefShare (без новых эндпоинтов):**
- Пре-Send: РЕДАКТИРУЕМЫЙ документ анониму — токенные GET+PATCH HTML по `X-Brief-Token` (token-версия существующих `getBriefAiFinalDocuments`/`updateBriefAiFinalDocument`). Чат видит ручные правки (передаём documentHtml, как сейчас). Деталь реализации — документ должен быть доступен при `ready_to_finalize` (finalize-on-ready либо рендер из `structured_data`).
- Пост-Send (ссылки в письме): на Send делаем `BriefShare.objects.get_or_create(brief=...)` — тот же механизм, которым клиент шарит бриф сейчас. В письме публичная ссылка на существующий просмотр `/shared-brief/<token>` (`public_brief_share_get`, `urls.py:194`) + скачивание PDF через существующий `public_brief_share_document_pdf` (`/service/public/brief-shares/<token>/documents/<docId>/pdf`, `urls.py:199`). Публично, без сессии, стабильно (токен BriefShare независим от anonymous_token, claim его не трогает). Новых PDF-эндпоинтов и download-токенов НЕ делаем.

**Webhook (новый):**
- `POST /service/public/briefs/ai/from-webhook`, заголовок `X-Aivus-Webhook-Key`. `_verify_vendor_webhook_key(request)` → vendor. `_create_inbound_brief(..., vendor, source="webhook")` — дорабатываем тело чтобы писать `source` на Brief и сразу создавать `Project(vendor, brief, status=RFP)`. Rate-limit: IP `60/h` (anti-brute, до резолва ключа) поверх `50/h` по vendor_id (после резолва).

**Vendor-read брифа (новый):**
- `GET /service/vendor/projects/<projectId>/brief/documents` и `.../documents/<documentId>/pdf` — авторизация по `project.vendor == request vendor`, группа VENDOR.

**Vendor settings (расширение):**
- `GET/PATCH /service/vendor/settings` (`user_views.py:470`, `_build_vendor_settings_response:551`): `slug`, `leadNotificationEmail` (валидация/коллизия → 409).
- `GET /service/vendor/webhook-key` + `POST /service/vendor/webhook-key/rotate`.

**Email (новый path):**
- `send_to_recipient_email(recipient_email, template, subject, context)` — без User-контекста (существующий `send_templated_email(user_id)` — `users/tasks.py:30` — рендерит `{user}`, для анона не годится).
- account-matching: existing email → `send_templated_email(user_id)` login-шаблон; не найден → `send_to_recipient_email` register-шаблон.
- Locale: `document_language` брифа, иначе Accept-Language, дефолт en.
- Новые шаблоны: `brief_sent_client_{en,ru}.html` (CTA регистрации с этим email + публичная ссылка `/shared-brief/<token>` на просмотр/скачивание; для existing email — «Войти» вместо регистрации), `vendor_lead_{en,ru}.html`.
- PDF клиенту прикладываем **вложением** в письмо (генерим существующим `brief_pdf`). Anymail поддерживает attachments.

### Frontend route/API константы

`appRoute.ts`: `BRANDED_BRIEF(slug)`, `BRANDED_BRIEF_DETAIL(slug, briefId)`, `BRANDED_BRIEF_SUCCESS(slug)`.
`apiRoute.ts`: `PUBLIC_BRIEF_BY_SLUG`, `PUBLIC_BRIEF_BY_SLUG_DRAFT`, `PUBLIC_BRIEF_SEND`, `CLIENT_BRIEF_SEND`, `PUBLIC_BRIEF_FINAL_DOCUMENTS(briefId)`, `VENDOR_PROJECT_BRIEF_PDF`, `VENDOR_WEBHOOK_KEY`, `VENDOR_WEBHOOK_KEY_ROTATE`, `VENDOR_SLUG_SUGGEST`.

## 7. Карта реализации

### Переиспользуется как есть
Анонимный token-стек, публичные chat/start/status/attachments/transcribe/detail, claim для клиентской стороны, `finalize_brief_task`/`generate_final_documents`/`brief_pdf`, `BriefChatPanel`, `pendingBrief.ts`/localStorage, VendorSettings лого/company_name, существующий `Project.brief` FK.

### Backend — net-new
| Файл | Изменение |
|---|---|
| `users/models.py:283` (VendorSettings) | `slug`, `lead_notification_email`; новая `VendorWebhookKey` |
| `projects/models.py:35` | `source` (скаляр); Project не трогаем, используем существующий `Project(vendor, brief, status)` |
| `core/enums.py` | `BriefSource` |
| миграции | VendorSettings slug+email; Brief source; VendorWebhookKey |
| `views_brief_v3.py` | `by-slug` detail/draft; токенные `final-documents` GET+PATCH для анона (редактируемый документ, token-версия существующего edit); `send` (public+client, async chain); `from-webhook`; `_verify_vendor_webhook_key`; доработка `_create_inbound_brief:1223`; ретрофит wix. PDF/публичный просмотр из письма — переиспользуем существующие `public_brief_share_get`/`public_brief_share_document_pdf` |
| `projects/tasks.py` | `mark_project_sent_task` (DRAFT→RFP), `send_emails_task` (get_or_create BriefShare для ссылки + PDF-вложение) |
| `projects/api/views.py` | vendor-read brief documents/PDF |
| `users/api/user_views.py:470,551` | settings slug/leadNotificationEmail; webhook-key get/rotate; slug-suggest (LLM) |
| `projects/api/urls.py` | новые роуты |
| `users/tasks.py` | `send_to_recipient_email` |
| новые шаблоны | `brief_sent_client_{en,ru}.html`, `vendor_lead_{en,ru}.html` |
| Django admin | удаление анонимных брифов-черновиков |

### Frontend — net-new
| Файл | Изменение |
|---|---|
| `app/brief/[slug]/page.tsx` | старт-экран + хедер-логин |
| `app/brief/[slug]/[briefId]/page.tsx` | редактор (AnonymousBriefEditor + редактируемый документ по токену, whiteLabel, Send) |
| `app/brief/[slug]/success/page.tsx` | success |
| `modules/client/BriefEditor/` редактируемый документ для анона | переиспользуем существующий компонент правки документа на токенных GET+PATCH (без PreVendors/Share/Download) |
| `services/.../publicBriefApi.ts` | `getPublicBriefBySlug`, `createBriefDraftBySlug`, `getPublicFinalDocuments`, `sendPublicBrief` |
| `app/app/@vendor/dashboard/page.tsx` + `modules/vendor/dashboard/PersonalLinkPanel.tsx` | блок ссылки на главной над ProjectList |
| `modules/vendor/VendorSettingsSection` | slug (+ Suggest), leadNotificationEmail, webhook-key UI |
| `services/.../vendorSettingsApi.ts` | slug/email/webhook-key/suggest |
| `middleware.ts` | `/brief` в public allowlist; CSP frame-ancestors для `/brief/*?embed=1` |
| `constants/appRoute.ts`, `apiRoute.ts` | новые роуты |

## 8. Безопасность и abuse

- **Slug**: `^[a-z0-9-]{3,40}$`, lowercase, без ведущих/замыкающих/двойных дефисов. Серверная проверка + перехват `IntegrityError` → 409.
- **Reserved slugs**: генерим из реальных top-level сегментов `Frontend/src/app/*` + служебные (`api, admin, auth, brief, public, public-brief, shared-brief, service, settings, vendor, client, www, go, embed, static, assets, success`). Один источник-константа.
- **Soft-delete вендора**: `deleted_at` через `.update()`, on_delete не срабатывает. Резолв slug и Send вручную фильтруют `deleted_at IS NULL`. PROTECT не используем.
- **Rate-limit** (фактические значения в коде, все по IP если не указано иное): `by-slug` GET 60/h; `by-slug` draft POST 30/h; публичный draft POST 6/h; публичный start POST 3/h; публичный chat POST 5/m; Send POST 10/h; wix POST 30/h; share GET 120/m; share PDF GET 60/m. Webhook POST — два слоя: IP 60/h (anti-brute, срабатывает до резолва ключа) поверх 50/h по vendor_id (срабатывает после резолва). IP-лимит намеренно выше vendor-лимита, чтобы легитимный вендор с одного серверного IP упирался в vendor-лимит, а не в anti-brute. Slug-suggest GET (дёргает LLM) 20/h по user.
- **Client lead email throttle** (H4): брендированное письмо «Your brief is ready» с PDF летит на произвольный recipient из анонимного Send. Помимо per-IP лимита Send, диспетч троттлится per-recipient независимо от брифа и IP: не более 5 писем на адрес в час, и один и тот же бриф не шлётся на один адрес повторно. Защита от бомбинга жертвы с пула IP.
- **Unverified-лид by design**: лид вендору создаётся до подтверждения email клиента — намеренно (go-to-market). Помечаем контакт unverified (seam). Фильтрация — Stage 3.
- **Webhook key**: `secrets.token_urlsafe(32)`, `hmac.compare_digest`. Ротация ломает старый мгновенно (popconfirm). Не в логи. `X-Aivus-Webhook-Key` (per-vendor) и `X-Aivus-Webhook-Secret` (Wix) — разные заголовки.
- **Anti-enumeration**: детект существующего email и развилка письма — в async-таске, ответ Send одинаков за константное время.
- **CSP/embed**: правка в `middleware.ts`. `/brief/*?embed=1` → `frame-ancestors *`, остальной домен жёсткий allowlist. Clickjacking-риск зафиксирован.
- **Анонимные черновики**: автоудаления нет; чистка вручную админом из Django admin.
- Перед PR — `security-review` на новые публичные эндпоинты, webhook-auth, send-флоу.

## 9. Аналитика

События: `branded_link_opened {slug, vendorId, embed}`, `branded_brief_started {slug, vendorId, briefId, authed}`, `branded_brief_send_clicked {briefId, vendorId, authed}`, `branded_brief_sent {briefId, vendorId, projectId, source}`, `branded_brief_claimed {briefId, clientId, newAccount}`, `vendor_lead_via_webhook {vendorId}`, `vendor_link_copied`/`vendor_embed_copied {vendorId}`, `existing_brief_reused {briefId, vendorId}`. Воронка opened → started → send_clicked → sent → claimed.

## 10. Тестирование

**Backend pytest:**
- slug: валидация, коллизия (IntegrityError→409), reserved, генерация/предложение при первом GET, fallback; резолв by-slug valid/invalid/soft-deleted.
- draft-by-slug: создаёт source=personal_link + Project(vendor, brief, status=DRAFT) (get_or_create, не дублируется при повторном заходе).
- Send: async chain финализирует если ready_to_finalize; существующий Project переходит DRAFT→RFP только после COMPLETED; переход идемпотентен (двойной Send → один RFP-проект); письма (клиент+вендор); account-matching (existing email → login-письмо, ответ Send одинаков); нет Send если `status >= RFP`. Для auth-выбора готового брифа Project создаётся на Send сразу в RFP.
- Маркеры лида: serialize_project отдаёт briefConversationStatus и hasContactEmail; DRAFT-лид помечен «в процессе», RFP — «новый».
- Webhook: валидный ключ → бриф (source=webhook) + Project(vendor, brief, RFP); невалидный/ревокнутый → 401; rate-limit по vendor_id.
- Soft-deleted vendor → slug не резолвится, Send отклонён.
- Vendor-read PDF: доступен владельцу проекта, чужому — 403/404.

**Frontend vitest:**
- PersonalLinkPanel: URL/Copy/Preview/Embed, empty state, позиция на дашборд-хоуме.
- Редактируемый документ анона + whiteLabel: PDF/Share/PreVendors/vendor_email скрыты; правка документа сохраняется (токенный PATCH); Send показан и disabled до finalized.
- Send-modal: email required для анона, отсутствует для auth.
- Settings: slug inline-валидация + Suggest.

**Playwright E2E (`make e2e-flows`, live-LLM):**
- «branded anon»: `/brief/<slug>` → start → диалог → finalize → Send с email → success → письмо в Mailpit → claim → регистрация → бриф в кабинете клиента → проект у вендора.
- «branded logged-in new»: логин → новый бриф → Send без email → проект у вендора.
- «branded logged-in existing»: выбор готового → Send → проект у вендора (тот же бриф), повторный Send тому же вендору недоступен.
- «account matching»: Send с зарегистрированным email → login-письмо → привязка к существующему.
- «webhook lead»: POST from-webhook с ключом → проект у вендора с source=webhook.

Главный инвариант — сквозной seam «клиент нажал Send → проект появился именно у этого вендора с правильным source» — ловим E2E.

## 11. Out of scope (seam под Stage 3-5)

Не делаем: inbox/mini-CRM лидов, статусы/верификация лида, ответ клиенту из кабинета — Stage 3; автогенерация оффера — Stage 4; редиректы старых slug / история slug; кастомные домены и сабдомены; расширенный брендинг (цвета, кастомный текст); resend письма; несколько notification-получателей; авточистка черновиков (только админ-удаление); slack/webhook-нотификации вендору; мультиязычный брендинг старт-экрана; логин/claim внутри iframe; passwordless/magic-link логин и пред-создание аккаунта анониму (Stage 2.1).

## 12. Принятые решения и открытые вопросы

Решено:
1. Embed на MVP — да, минимально (iframe-сниппет + `?embed=1` + CSP-правка), только анонимный путь.
2. Вендору отдаётся не копия, а прямая связь: на Send создаётся `Project(vendor, brief)` через существующий FK. Один бриф может иметь проекты у разных вендоров. Вендор только читает.
3. Email = существующий vendor-аккаунт: для MVP шлём login-письмо, лид у вендора создаётся независимо; принудительно роль/группу не переключаем (модель `User.group` — одно активное значение, будущий тоггл ролей в Settings этому не противоречит; Client-профиль создаётся лениво на claim без смены группы).
4. Повторная отправка одного брифа одному вендору запрещена: если Project `(brief, vendor)` есть — Send не показываем.
5. Notification email — одно поле, дефолт owner.email.
6. Письмо вендору — простой шаблон без PDF, ведёт в кабинет.
7. Slug — генерится автоматически (LLM-предложение) при первом заходе, вендор может менять. Опционален до первого использования ссылки.
8. Адрес — path-based `go.aivus.co/brief/<slug>`. Сабдомены не делаем.
9. Vendor-read PDF — отдельный эндпоинт с авторизацией по владению проектом.
10. Перед отправкой клиент обязательно видит финальный текст брифа и **может его редактировать сразу** (как в доке-источнике): напрямую (токенный PATCH) и/или через чат. Переиспользуем существующий механизм правки документа, для анона — token-версия. После логина — полный существующий редактор без изменений. White-label лишь прячет Download/Share/PreVendors на брендированной странице.
11. Старые slug-ссылки после смены не поддерживаем (404).
12. Старые/брошенные анонимные черновики — без автоудаления; чистит админ из админки.
13. Блок ссылки — на главной дашборда (целевое действие вендора), не в сайдбаре.
14. Момент создания vendor-проекта — СРАЗУ при старте брифа на странице вендора, `status=DRAFT` («лид в процессе заполнения» — уже полезен). На Send → `status=RFP`. В списке вендора лид помечается стадией (в процессе/новый) и наличием email (`brief.contact_email`). Для залогиненного выбора готового брифа проект создаётся на Send сразу в RFP. Брошенные DRAFT-лиды чистит только админ (см. §8).
15. Письмо анониму — с явным CTA «зарегистрируйся ИМЕННО с этим email, чтобы сохранить бриф»; ссылка ведёт на регистрацию с предзаполненным и залоченным email + claim. Аккаунт заранее НЕ создаём и пароль не генерим (рекомендация): иначе орфан-аккаунты, непрошеные аккаунты на чужие/опечатанные email (лид-то создаётся до верификации), небезопасная рассылка паролей. Регистрация по ссылке = верификация владения почтой. Если позже нужен zero-friction — magic-link (passwordless), не генерёный пароль; это Stage 2.1.
16. Доступ к PDF/брифу из письма — переиспользуем существующий публичный `BriefShare` (тот же шеринг, что у клиента сейчас): на Send делаем `get_or_create BriefShare`, в письме публичная ссылка `/shared-brief/<token>` (просмотр + PDF) и PDF вложением. Новых PDF-эндпоинтов и download-токенов не делаем; вопрос «токен после claim» снят (BriefShare-токен независим).
