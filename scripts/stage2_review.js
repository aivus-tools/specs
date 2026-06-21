export const meta = {
  name: 'stage2-review-16',
  description: 'Final confirming release review #16 of Stage 2 Personal Vendor Link after round-15 race/TTL fixes',
  phases: [
    { title: 'Review', detail: '6 independent lenses over the full Stage 2 diff + round-8 fixes' },
    { title: 'Verify', detail: 'adversarial refute pass per finding (2 skeptics on critical/high)' },
    { title: 'Synthesize', detail: 'dedup, classify mustFix/shouldFix/falsePositive, release verdict' },
  ],
}

const BE = 'Backend/aivus_backend'
const BE_BASE = '17ab0580549710874af236aff9f1a2c63678f4e4'
const FE = 'Frontend'
const FE_BASE = 'd68b72e7885dedec53dd4c6411b218a0242b6cd5'
const PRD = 'Specs/PRD_STAGE2_PERSONAL_VENDOR_LINK.md'

const CTX = `
КОНТЕКСТ. ФИНАЛЬНОЕ подтверждающее релизное ревью Stage 2 "Personal Vendor Link" (white-label lead capture) — раунд #16, после пятнадцати раундов фиксов. Ревью #13/#14/#15 дали вердикт CLEAN (релиз-блокеров нет); round-15 закрыл 2 остаточных low (гонка двойной финализации в claim, залипание Send pending при kill воркера через TTL). Цель #16: подтвердить, что round-15 фиксы корректны и НЕ внесли регрессий, и сделать финальный полный проход — НАЙТИ всё, что ещё блокирует полноценный релиз. Работай из корня репо /Users/ipolotsky/Develop/Aivus.

РЕПОЗИТОРИИ И ДИАПАЗОНЫ (читай и diff, и текущее состояние файлов на HEAD):
- Backend: git -C ${BE} diff ${BE_BASE}...feature/stage-1-vendor-link  (54 файла, +9120)
- Frontend: git -C ${FE} diff ${FE_BASE}...feature/stage-1-vendor-link  (67 файлов, +6460; в round-15 НЕ менялся)
- PRD (контракт продукта): ${PRD}

АРХИТЕКТУРА (инварианты, не баги): связь "бриф у вендора" = существующий Project(vendor, brief, status), БЕЗ копий брифа и БЕЗ новых FK на Brief; единственное новое поле Brief.source. Проект создаётся при старте брифа (DRAFT) → RFP на Send. PDF/публичный просмотр в письме переиспользуют существующий BriefShare. Анонимный документ редактируется через токенные final-documents GET+PATCH. HMAC-middleware (core/middleware.py) ставит request.user_data (НЕ request.user). Публичный домен go.aivus.co. Django доступен ТОЛЬКО через Next.js-прокси (middleware.ts /service/* → rewrite на API_URL); прямого Traefik→Django маршрута нет — поэтому Next.js может авторитетно задавать client IP, а Django ему доверять. Контракт client IP: FE Next.js ставит x-aivus-forwarded-client (правый-крайний входящего XFF), BE resolve_client_ip (core/ratelimit.py) читает HTTP_X_AIVUS_FORWARDED_CLIENT первым и доверяет безусловно.

ROUND-15 ФИКСЫ (свежие — состязательно проверить в первую очередь: реально ли чинят и не внесли ли регрессий, оба backend):
47437ce client_brief_ai_claim перечитывает бриф через select_for_update внутри atomic и добавляет условие "and not brief.pending_task_id" в should_finalize → claim не диспатчит второй finalize поверх летящего анонимного (нет лишнего платного LLM). 0401d79 TTL на Send pending-маркер: новое поле Brief.pending_task_started_at (миграция 0043), константа SEND_PENDING_MAX_AGE_SECONDS=600, _dispatch_send ставит таймштамп, хелпер _send_pending_expired атомарно сбрасывает просроченный маркер в обоих status-эндпоинтах → status отдаёт failed и re-Send разблокирован (не залипает при SIGKILL воркера). Одиночные таски (generate_first_reply, finalize-on-ready) таймштамп НЕ ставят → TTL для них не срабатывает, их AsyncResult-логика не задета.
ROUND-13/14 ФИКСЫ (верифицированы #15): sanitizeReturnUrl робастный (new URL + origin); saveTimerRef.current=null в finally; PasswordForm pending→BRIEF_CLAIM.

ROUND-8..12 ФИКСЫ (верифицированы ранее, перепроверять только при подозрении на регрессию от round-13): vendor_email PII закрыт на ВСЕХ слоях (shared-brief, PDF-attachment, final-documents GET/PATCH, public chat updatedDocuments, vendor-read эндпоинты, anon LLM-контекст); X-Aivus-Forwarded-Client контракт + authService (credentials+google); 7 client + 9 auth + 3 legacy rate-limit keys; finalize_failed флаг + chat-retry + 409 gate после Send + ordering; best-effort письма с раздельными маркерами client/vendor + rollback обеих веток; claim 404/403; getProductionBriefHtml (чеклист не утекает в production_brief); flush forwardRef обе ветки; 409-handling в чате и обоих редакторах.

ПОДТВЕРЖДЁННЫЕ НЕ-БЛОКЕРЫ (НЕ репортить как блокеры, опровергнуты ранее): orphan Client profile на lazy _ensure_client_profile (DB-мусор, нет потери данных/PII); revoked BriefShare reuse в mark_project_sent_task (ни один текущий сценарий не ломается — в anon-флоу бриф новый, в auth pick-existing клиенту не шлётся email со share-токеном); инструментирование аналитики §9 (документированный follow-up); embed clickjacking по ?embed=1 (осознанно PRD §4ж/§8); live-LLM E2E требует сид env.

КЛЮЧЕВЫЕ ФАЙЛЫ. Backend: projects/api/views_brief_v3.py, projects/api/serializers.py, projects/brief_emails.py, projects/tasks.py, projects/models.py, core/enums.py (CLIENT_FACING_DOCUMENT_KINDS), core/decorators.py (conditional_ratelimit), core/middleware.py, core/slugs.py, users/api/user_views.py, users/api/auth_views.py, config/settings/production.py, миграции 0038-0040. Frontend: app/brief/[slug]/page.tsx, app/brief/[slug]/[briefId]/page.tsx, modules/client/BriefEditor/*, app/app/@client/brief/claim/[briefId]/page.tsx, app/app/@client/_components/ClientLayout, auth RegisterForm/PasswordForm, middleware.ts, modules/vendor/dashboard/*, services/client/*Api.ts, helpers/pendingBrief.ts, constants/*.

КОНТРАКТ ОШИБОК Send (machine codes): email_required, invalid_email, not_ready, brief_not_found, agency_not_found, vendor_mismatch, already_sent, still_generating, already_being_sent.

ИЗВЕСТНЫЕ НЕ-БЛОКЕРЫ (не репортить как блокеры): инструментирование аналитики воронки PRD §9 (документированный follow-up); embed clickjacking frame-ancestors по ?embed=1 (осознанно зафиксировано PRD §4ж/§8); live-LLM E2E требует сид env (не запускается в этом ревью).

ПРАВИЛА. Только реальные дефекты с доказательством (file:line + цитата кода + почему ломает релиз). НЕ стилистика, НЕ вкусовщина. Severity: critical (PII/security/потеря данных/деньги), high (сломанный основной флоу/контракт), medium (краевой кейс/UX-деградация), low (мелочь). Если ничего по линзе — верни пустой findings.
`

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'severity', 'file', 'problem', 'evidence', 'fix'],
        properties: {
          id: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          file: { type: 'string' },
          line: { type: 'string' },
          problem: { type: 'string' },
          evidence: { type: 'string', description: 'цитата кода/контракта, доказывающая дефект' },
          fix: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['isReal', 'confidence', 'severity', 'reasoning'],
  properties: {
    isReal: { type: 'boolean', description: 'дефект реален и воспроизводим в живом флоу' },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'], description: 'severity по итогу проверки (мог скорректироваться)' },
    reasoning: { type: 'string' },
  },
}

const SYNTH_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'summary', 'mustFix', 'shouldFix', 'falsePositives'],
  properties: {
    verdict: { type: 'string', enum: ['clean', 'needs-fixes'], description: 'clean только если нет ни одного mustFix' },
    summary: { type: 'string' },
    mustFix: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'severity', 'file', 'problem', 'fix'],
        properties: {
          id: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'high'] },
          file: { type: 'string' },
          problem: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
    shouldFix: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'severity', 'file', 'problem', 'fix'],
        properties: {
          id: { type: 'string' },
          severity: { type: 'string', enum: ['medium', 'low'] },
          file: { type: 'string' },
          problem: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
    falsePositives: {
      type: 'array',
      items: { type: 'string' },
    },
  },
}

const LENSES = [
  {
    key: 'contract',
    prompt: `${CTX}\n\nТВОЯ ЛИНЗА — КОНТРАКТ FE↔BE. Сверь фронтовые вызовы (services/client/*Api.ts, constants/apiRoute.ts) с бэковыми роутами и сериализаторами. Ищи: рассинхрон URL/метода/payload; обработку ВСЕХ machine-кодов ошибок Send на фронте (есть ли маппинг каждого: email_required/invalid_email/not_ready/brief_not_found/agency_not_found/vendor_mismatch/already_sent/still_generating/already_being_sent); контракт статус-поллинга final-documents (что фронт ждёт vs что бэк отдаёт, включая finalizeFailed после round-8 d749d01); shape final-documents GET/PATCH (kinds, поля); slug suggest/check; поля сериализатора public shared/public brief (не утёк ли vendor_email). Особо: SF-8 был про то, что бэк отдаёт оба client-facing kind — проверь, что фронтовый WhiteLabelDocumentPanel (836441b) реально совпал с бэком.`,
  },
  {
    key: 'backend',
    prompt: `${CTX}\n\nТВОЯ ЛИНЗА — BACKEND КОРРЕКТНОСТЬ. Глубоко прочитай views_brief_v3.py, tasks.py, brief_emails.py, user_views.py, auth_views.py, models.py, миграции 0038-0040. Ищи: гонки в Send/finalize цепочке (set pending → RFP → emails → finalize), идемпотентность Celery-тасок, транзакционные границы (atomic), корректность миграции 0038 dedup RunPython (не падает ли на проде с дублями), pending_task_error/pending_task_id жизненный цикл, корректность round-8 finalize-фикса (d749d01 — не зациклится ли, не потеряет ли валидную финализацию), BriefShare-в-atomic (77c8595 — нет ли дедлока/повторного письма). N+1, отсутствие select_related на горячих путях. Логические баги в _dispatch_send/_dispatch_finalize_if_ready.`,
  },
  {
    key: 'frontend',
    prompt: `${CTX}\n\nТВОЯ ЛИНЗА — FRONTEND КОРРЕКТНОСТЬ. Прочитай app/brief/[slug]/page.tsx, [briefId]/page.tsx, BriefEditor/* (Anonymous/Authenticated/BriefFinalPackage/BriefSharedView/WhiteLabelDocumentPanel/SendBriefModal/BriefSelectModal), claim/[briefId]/page.tsx, ClientLayout, RegisterForm/PasswordForm, middleware.ts, helpers/pendingBrief.ts. Ищи: баги состояния/роутинга, RTK Query кэш/инвалидация (round-8 66d9d53 SentBriefIds — реально ли скрывается Send при возврате через history.back), claim-флоу (round-8 29d115b — не маскирует ли 404-as-success реальные ошибки claim; чистится ли cookie во всех ветках), draft-resume на cookie (90740e0 — не протекает ли черновик между разными вендорами/юзерами на общем устройстве; правильный ли ключ/срок), middleware XFF (c6e81f5 — корректный ли заголовок, нет ли спуф-вектора), WhiteLabelDocumentPanel табы (836441b — key/ремоунт editor, потеря несохранённых правок при переключении), useEffect-зависимости, гонки автосейва.`,
  },
  {
    key: 'security',
    prompt: `${CTX}\n\nТВОЯ ЛИНЗА — БЕЗОПАСНОСТЬ. Жёстко. Ищи: (1) PII vendor_email/любые vendor-данные, утекающие клиенту ВЕЗДЕ — public shared-brief сериализатор, public-brief, final-documents GET, PDF-вложение письма (round-8 dd678a6), email-тело; (2) rate-limit — реально ли изолированы бакеты после round-8 5e9194e (per-user по user_data['id'], per-vendor по vendor.id, per-IP); работает ли key-callable когда user_data отсутствует (аноним); не остался ли key="user" где-то ещё на платных/тяжёлых эндпоинтах (особенно LLM: slug-suggest, send, AI chat turn); fail-closed cache (84f88fe) — не положит ли он легитимный трафик при флапе Redis; (3) IP-резолв resolve_client_ip + XFF forwarding (cc23746/c6e81f5) — спуфинг client IP через подделанный x-forwarded-for, off-by-one в RATELIMIT_TRUSTED_PROXY_COUNT; (4) авторизация токенных эндпоинтов (anon final-documents GET/PATCH, claim) — можно ли по чужому токену/перебором; объектные права (IDOR) на brief/project; (5) CSP/embed; (6) валидация slug (инъекции, reserved, коллизии). Перепроверь, что critical PII-фикс прошлых раундов (vendor_email из shared-brief) не регрессировал.`,
  },
  {
    key: 'round15-regression',
    prompt: `${CTX}\n\nТВОЯ ЛИНЗА — РЕГРЕССИИ ROUND-15 (свежие фиксы, главный фокус). По каждому round-15 коммиту (backend 47437ce/0401d79) прочитай diff (git -C ${BE} show <sha>) и ответь: (а) реально ли чинит; (б) не внёс ли регрессию/новый дефект. Состязательно атакуй: (1) 47437ce claim guard — select_for_update реально внутри atomic-блока (не вне), брифа lock корректен; условие "and not brief.pending_task_id" точно предотвращает второй finalize и НЕ ломает легитимный claim-finalize (когда pending нет, документов нет, ready_to_finalize → должен задиспатчить); нет ли дедлока с параллельным _dispatch_finalize_if_ready (оба берут select_for_update на тот же row — порядок/таймаут). (2) 0401d79 TTL — поле pending_task_started_at + миграция 0043 дефолт null ок для существующих строк; SEND_PENDING_MAX_AGE_SECONDS=600 достаточно над худшей длительностью Send (не отрубит ли легитимный долгий Send); _send_pending_expired атомарно сбрасывает (нет гонки с реально завершающейся таской, которая в этот момент ставит COMPLETED?); таймштамп ставится ТОЛЬКО для Send, не для finalize-on-ready/generate_first_reply (иначе их AsyncResult-логику задело); сброшенный маркер реально разблокирует re-Send (guard already_being_sent ~1488); просрочка отдаёт failed, а не молчит; что если воркер на самом деле ещё жив и доделает Send ПОСЛЕ TTL-сброса — не будет ли двойного Send/двойного письма (emails_sent_at/vendor_notified_at guard ловит?). Затем — БЫСТРЫЙ финальный проход на ЛЮБЫЕ другие релиз-блокеры во всём Stage 2 diff (не только round-15): что-то упущенное за 15 раундов. Верни findings ТОЛЬКО на реальные проблемы.`,
  },
  {
    key: 'completeness',
    prompt: `${CTX}\n\nТВОЯ ЛИНЗА — ПОЛНОТА И ТЕСТЫ. Сверь реализацию с PRD (${PRD}) по всем флоу: (а) аноним стартует бренд-бриф → правит → Send → email с токеном → claim; (б) залогиненный клиент → выбор готового брифа → Send; (в) существующий email → login/register → claim; (г) webhook-lead от вендора; (д) vendor dashboard link/copy/preview/embed/settings slug. Ищи НЕпокрытые PRD-требования, краевые кейсы без обработки (отключённый вендор, коллизия slug, повторный Send, закрытая вкладка/resume, дубль-claim, бриф ещё генерируется на момент Send), и дыры в тестах (что заявлено фиксами, но не покрыто pytest/vitest). Проверь, что заявленные round-8 тесты реально существуют и проверяют именно то (прочитай тест-файлы). Аналитику §9 НЕ репортить (известный follow-up).`,
  },
]

function verifyPrompt(f, lensKey, idx) {
  const angle = idx === 0
    ? 'Проверь КОРРЕКТНОСТЬ: прочитай код по file:line и докажи или опровергни дефект технически.'
    : 'Проверь ВОСПРОИЗВОДИМОСТЬ В ЖИВОМ ФЛОУ: пройди реальный пользовательский сценарий и реши, сработает ли дефект на проде или его глушит другой слой.'
  return `${CTX}\n\nТЫ СКЕПТИК-ВЕРИФИКАТОР. По умолчанию считай находку ЛОЖНОЙ, пока не докажешь обратное по коду. ${angle}\n\nНАХОДКА (линза ${lensKey}):\nseverity: ${f.severity}\nfile: ${f.file}:${f.line || '?'}\nproblem: ${f.problem}\nevidence: ${f.evidence}\nproposed fix: ${f.fix}\n\nОткрой указанные файлы, проверь цитату и логику. Учитывай известные не-блокеры и архитектурные инварианты из контекста (их НЕ считать дефектом). Верни isReal (реален ли релиз-дефект), confidence, severity (скорректируй если надо), reasoning со ссылкой на конкретные строки.`
}

phase('Review')
const reviewed = await pipeline(
  LENSES,
  lens => agent(lens.prompt, { schema: FINDINGS_SCHEMA, phase: 'Review', label: `review:${lens.key}`, agentType: 'general-purpose' }),
  (review, lens) => {
    const findings = (review && review.findings) || []
    return parallel(findings.map((f) => () => {
      const n = (f.severity === 'critical' || f.severity === 'high') ? 2 : 1
      return parallel(Array.from({ length: n }, (_unused, i) => () =>
        agent(verifyPrompt(f, lens.key, i), { schema: VERDICT_SCHEMA, phase: 'Verify', label: `verify:${lens.key}:${f.id}`, agentType: 'general-purpose' })
      )).then((verdicts) => {
        const vs = verdicts.filter(Boolean)
        const realVotes = vs.filter((v) => v.isReal).length
        const survives = vs.length > 0 && realVotes >= Math.ceil(vs.length / 2)
        const sev = vs.length > 0 ? vs.map((v) => v.severity).sort()[0] : f.severity
        return { lens: lens.key, id: f.id, severity: sev, origSeverity: f.severity, file: f.file, line: f.line, problem: f.problem, evidence: f.evidence, fix: f.fix, verdicts: vs, realVotes, totalVotes: vs.length, survives }
      })
    }))
  }
)

const allFindings = reviewed.flat().filter(Boolean)
const confirmed = allFindings.filter((f) => f.survives)
log(`Findings: ${allFindings.length} total, ${confirmed.length} survived adversarial verify`)

phase('Synthesize')
const synthInput = confirmed.map((f) =>
  `[${f.lens}/${f.id}] sev=${f.severity} (votes ${f.realVotes}/${f.totalVotes}) ${f.file}:${f.line || '?'}\n  problem: ${f.problem}\n  fix: ${f.fix}\n  verdicts: ${f.verdicts.map((v) => `${v.isReal ? 'REAL' : 'false'}/${v.confidence}: ${v.reasoning}`).join(' || ')}`
).join('\n\n')

const rejected = allFindings.filter((f) => !f.survives).map((f) => `[${f.lens}/${f.id}] ${f.file}: ${f.problem} (refuted ${f.totalVotes - f.realVotes}/${f.totalVotes})`).join('\n')

const synthesis = await agent(
  `${CTX}\n\nТЫ СИНТЕЗАТОР релизного ревью #9. Ниже — находки, ПРОШЕДШИЕ состязательную верификацию (хотя бы большинством голосов скептиков). Сдедуплицируй (одна проблема из разных линз = одна запись), отбрось всё, что на самом деле покрыто архитектурными инвариантами или известными не-блокерами, и классифицируй:\n- mustFix: critical/high РЕАЛЬНЫЕ релиз-блокеры (PII/безопасность/деньги/сломанный основной флоу/контракт). Только то, что обязано быть починено до релиза.\n- shouldFix: medium/low — стоит починить, но не блокер.\n- falsePositives: что после взвешивания не дефект (с краткой причиной).\nverdict='clean' ТОЛЬКО если mustFix пуст.\n\n=== ПОДТВЕРЖДЁННЫЕ НАХОДКИ ===\n${synthInput || '(нет подтверждённых находок)'}\n\n=== ОТБРОШЕНО ВЕРИФИКАЦИЕЙ (для справки, обычно в falsePositives) ===\n${rejected || '(нет)'}`,
  { schema: SYNTH_SCHEMA, phase: 'Synthesize', label: 'synthesis', agentType: 'general-purpose' }
)

return {
  verdict: synthesis.verdict,
  summary: synthesis.summary,
  counts: { totalFindings: allFindings.length, confirmed: confirmed.length, mustFix: synthesis.mustFix.length, shouldFix: synthesis.shouldFix.length },
  mustFix: synthesis.mustFix,
  shouldFix: synthesis.shouldFix,
  falsePositives: synthesis.falsePositives,
}
