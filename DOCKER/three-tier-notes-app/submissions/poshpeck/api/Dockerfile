# Stage 1: Build Python dependencies
FROM python:3.12-slim AS builder

WORKDIR /install

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# Stage 2: Create the production image
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy installed dependencies from the builder
COPY --from=builder /install /usr/local

# Copy the Flask application
COPY app.py .

# Create a non-root application user
RUN groupadd --system app && \
    useradd --system --gid app --no-create-home app && \
    chown -R app:app /app

# Run as a non-root user
USER app

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
