# Stage 1: Build the application

FROM python:3.13-slim AS build

WORKDIR /api

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Create the final image

FROM python:3.13-slim AS production

WORKDIR /api

RUN groupadd -r apigroup && useradd -r -g apigroup -d /api -s /sbin/nologin -c "Docker image user" appuser

COPY --from=build /install /usr/local

COPY --chown=appuser:apigroup app.py .

USER appuser

EXPOSE 8000

CMD [ "gunicorn", "app:app", "--bind", "0.0.0.0:8000" ]

