# HandOff-Backend

Бэкенд сервиса бронирования оборудования лаборатории. Java 21, Spring Boot, PostgreSQL.

## База данных (PostgreSQL в Docker)

Нужен Docker с Compose.

```bash
cp .env.example .env          # один раз, затем поменяй POSTGRES_PASSWORD
docker compose up -d          # запустить базу
docker compose ps             # статус, должно быть healthy
docker compose exec postgres psql -U handoff -d handoff   # консоль psql
docker compose down           # остановить, данные сохранятся
docker compose down -v        # остановить и удалить данные
```

Локальный compose — `compose.dev.yaml`, он выбран через `COMPOSE_FILE` в `.env`, поэтому `-f` указывать не нужно.
`compose.prod.yaml` — для тестового стенда, пока пустой.

Подключение из DBeaver, IntelliJ и т. п.: хост `localhost`, порт `5432`, база `handoff`, пользователь `handoff`, пароль из `.env`.
Если порт 5432 занят, поменяй `POSTGRES_PORT` в `.env`.
Порт открыт только на `127.0.0.1`: с других машин в сети к базе не подключиться.

База и пользователь создаются при первом запуске из переменных `.env`.
SQL- и sh-скрипты из `docker/postgres/init/` выполняются тоже только при первом запуске на пустом томе;
чтобы применить их заново, выполни `docker compose down -v` и снова `up -d`.

## Приложение

```bash
./gradlew bootRun     # запуск, проверка: GET http://localhost:8080/api/v1/ping
./gradlew test        # тесты
```
