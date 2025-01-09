FROM python:3.12 AS builder

RUN pip install poetry

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache \
    POETRY_VERSION=1.8.5

WORKDIR /app

COPY pyproject.toml poetry.lock ./service/
RUN touch README.md
COPY --from=common ./ ./common

WORKDIR /app/service

RUN --mount=type=cache,target=$POETRY_CACHE_DIR poetry install --without dev --no-root

# Cleanup the images for production
FROM gcr.io/distroless/python3-debian12:nonroot AS runtime

ENV VIRTUAL_ENV=/app/service/.venv \
    PATH="/app/service/.venv/bin:$PATH"

COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}
COPY src/service ./service

CMD [ "uvicorn", "--log-level", "warning", "--app-dir", "service", "main:app" ,"--host", "0.0.0.0" ]