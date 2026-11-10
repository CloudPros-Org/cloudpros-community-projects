FROM python:3.12-alpine AS builder
WORKDIR /app
COPY ./api/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-alpine
LABEL service="Notes API"
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY ./api/app.py ./

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]

RUN adduser -D app 
USER app

EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
