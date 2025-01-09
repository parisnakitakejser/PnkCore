FROM python:3.12 AS builder

RUN pip install poetry

WORKDIR /app

COPY pyproject.toml poetry.lock ./service/
RUN touch README.md

WORKDIR /app/service

RUN poetry install --without dev --no-root

COPY src/service ./service

CMD [ "uvicorn", "--log-level", "warning", "--app-dir", "service", "main:app" ,"--host", "0.0.0.0" ]