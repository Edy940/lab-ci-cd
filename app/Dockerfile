FROM python:3.10-alpine3.21
LABEL MANTAINER="Seu Nome"

WORKDIR /app

COPY . /app

RUN apk add --no-cache curl \
    && pip install --trusted-host pypi.python.org -r requirements.txt

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]