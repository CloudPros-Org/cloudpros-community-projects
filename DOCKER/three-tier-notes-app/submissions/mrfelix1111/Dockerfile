# Stage 1: Install dependencies
FROM python:3.12-slim AS builder

WORKDIR /install

COPY api/requirements.txt .

RUN pip install --no-cache-dir --prefix=/install/deps -r requirements.txt


# Stage 2: Build the smaller runtime image
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/usr/local/lib/python3.12/site-packages

RUN groupadd --system appgroup && \
    useradd --system --gid appgroup --no-create-home appuser

WORKDIR /app

COPY --from=builder /install/deps /usr/local
COPY --chown=appuser:appgroup api/ .

USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
