# Руководство по серверной части для `offline_first_sync_drift`

## Зачем нужен отдельный гайд

`offline_first_sync_drift` ожидает от сервера жёстко заданный REST-контракт: идемпотентные PUT-запросы, стабильную пагинацию и проверку конфликтов по `updatedAt`. Этот документ сводит все требования в одном месте и помогает backend-команде быстро подготовить API.

## Обязательные REST-эндпоинты

| Метод | URL | Назначение |
|-------|-----|------------|
| `GET` | `/{kind}` | Список записей с фильтрацией и пагинацией |
| `POST` | `/{kind}` | Создание новой записи |
| `PUT` | `/{kind}/{id}` | Полное обновление записи с проверкой конфликтов |
| `DELETE` | `/{kind}/{id}` | Удаление (hard или soft) |

`{kind}` - имя сущности (пример: `daily_feeling`, `health_record`). Дополнительные фильтры (`updatedSince`, `afterId`, `includeDeleted`) передаются как query-параметры.

## Обязательные поля моделей

Каждая синхронизируемая запись должна включать:

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | `string` | Уникальный идентификатор (обычно UUID) |
| `updatedAt` | `datetime` | Время последнего серверного обновления (UTC) |
| `deletedAt` | `datetime?` | Метка soft-delete (опционально) |

```json
{
  "id": "abc-123",
  "mood": 5,
  "energy": 7,
  "updatedAt": "2025-01-15T10:30:00Z",
  "deletedAt": null
}
```

> `updatedAt` выставляется **строго на сервере** при каждом апдейте - на него опирается конфликт-детектор.

## PUT: конфликты, force-update и идемпотентность

Клиент присылает `_baseUpdatedAt` (когда запись была получена) и может добавлять заголовки:

- `X-Idempotency-Key` - уникальный ключ операции, позволяет безопасно ретраить запрос, ожидая повтор того же ответа.
- `X-Force-Update: true` - используется после client-side merge, чтобы сервер пропустил проверку конфликта и записал объединённые данные.

### Базовый алгоритм обработки PUT

1. Прочитать `X-Idempotency-Key`. Если операция уже выполнялась, вернуть сохранённый ответ.
2. Найти запись: `existing = repo.find(kind, id)`. Если не существует, `404`.
3. Считать `_baseUpdatedAt` из тела (и удалить из payload).
4. Если `forceUpdate = false` и `existing.updatedAt > baseUpdatedAt`, вернуть `409 conflict` с полем `current`, содержащим актуальную запись.
5. Очистить payload от системных полей (`id`, `updatedAt`, `_baseUpdatedAt` и т. д.).
6. Обновить запись, присвоив новый `updatedAt` на сервере.
7. Вернуть обновлённую запись и закэшировать ответ по `X-Idempotency-Key` на 24 часа.

### Пример на Node.js + Query Builder

```javascript
async function handlePut(req, res) {
  const { kind, id } = req.params;
  const idempotencyKey = req.header('x-idempotency-key');

  if (idempotencyKey) {
    const cached = await cache.get(`idempotency:${idempotencyKey}`);
    if (cached) return res.json(cached);
  }

  const existing = await db(kind).where({ id }).first();
  if (!existing) return res.status(404).json({ error: 'not_found' });

  const forceUpdate = req.header('x-force-update') === 'true';
  const payload = { ...req.body };
  const baseUpdatedAt = payload._baseUpdatedAt;
  delete payload._baseUpdatedAt;

  if (!forceUpdate && baseUpdatedAt) {
    if (new Date(existing.updated_at) > new Date(baseUpdatedAt)) {
      return res.status(409).json({
        error: 'conflict',
        current: existing,
      });
    }
  }

  const cleaned = stripSystemFields(payload); // убираем id/updatedAt и прочие служебные поля

  await db(kind)
    .where({ id })
    .update({
      ...cleaned,
      updated_at: new Date().toISOString(),
    });

  const result = await db(kind).where({ id }).first();

  if (idempotencyKey) {
    await cache.set(`idempotency:${idempotencyKey}`, result, 86400);
  }

  return res.json(result);
}
```

При ответе `409` важно вернуть актуальное состояние (`current`), чтобы клиент смог объединить данные и повторить запрос уже с `X-Force-Update: true`.

## Пагинация и выборка изменений

### Пример запроса

```http
GET /daily_feeling?updatedSince=2025-01-01T00:00:00Z&limit=500&afterId=xyz&includeDeleted=true
```

| Параметр | Описание |
|----------|----------|
| `updatedSince` | Вернуть записи, обновлённые после указанной метки |
| `limit` | Максимум записей в ответе (рекомендуется 500) |
| `afterId` | Последний полученный `id` для стабильного курсора |
| `includeDeleted` | Включить soft-deleted записи (нужно для синка) |

### Формат ответа

```json
{
  "items": [
    {"id": "abc-123", "mood": 5, "updatedAt": "2025-01-15T10:00:00Z"},
    {"id": "def-456", "mood": 3, "updatedAt": "2025-01-15T10:05:00Z"}
  ],
  "nextPageToken": "eyJ0cyI6IjIwMjUtMDEtMTVUMTA6MDU6MDBaIiwiaWQiOiJkZWYtNDU2In0="
}
```

### Обеспечение стабильной пагинации

```sql
-- Курсор из пары (updated_at, id) даёт последовательный порядок
SELECT *
FROM daily_feeling
WHERE
  (updated_at > :updatedSince)
  OR (updated_at = :updatedSince AND id > :afterId)
ORDER BY updated_at ASC, id ASC
LIMIT :limit;
```

> Если база не поддерживает составные курсоры, можно кодировать пару `(updatedAt, id)` в `nextPageToken` (например, в base64) и раскладывать при следующем запросе.

## Чеклист для сервера

- [ ] У каждой модели есть `updatedAt`, задаваемый сервером.
- [ ] Опциональная поддержка `deletedAt` для soft-delete.
- [ ] `GET /{kind}` принимает `updatedSince`, `limit`, `afterId`, `includeDeleted`.
- [ ] Пагинация стабильна: сортировка по `(updatedAt, id)` и курсор, сохраняющий оба значения.
- [ ] Ответ `GET` отдает `{ "items": [...], "nextPageToken": "..." }`.
- [ ] PUT проверяет `_baseUpdatedAt`, возвращает `409` с `current` при конфликте.
- [ ] Поддерживаются заголовки `X-Force-Update` и `X-Idempotency-Key` (24ч cache).
- [ ] `POST/PUT` возвращают свежую запись (с новым `updatedAt`), чтобы клиент сразу обновил локальный кэш.

## Дополнительные материалы

- E2E-проверка спецификации лежит в [`packages/offline_first_sync_drift_rest/test/e2e`](../packages/offline_first_sync_drift_rest/test/e2e) - можно использовать как референсную реализацию для backend-прототипа.

