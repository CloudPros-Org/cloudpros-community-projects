FROM python:3.12-slim AS base

WORKDIR /app

COPY api/requirements.txt .

RUN pip install --prefix=/packages -r requirements.txt

#final stage 
FROM python:3.12-slim

RUN useradd appuser

WORKDIR /app

COPY --from=base /packages /usr/local

COPY api/app.py .

USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
