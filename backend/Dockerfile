FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd --create-home --uid 10001 app \
    && mkdir -p /var/lib/alphaloop/tenants /freqtrade/user_data \
    && chown -R app:app /app /var/lib/alphaloop /freqtrade \
    && chmod 0755 /var/lib/alphaloop/tenants
USER app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
