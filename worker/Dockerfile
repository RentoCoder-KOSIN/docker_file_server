FROM python:3.12-slim
WORKDIR /app
# libmagic (python-magic 用)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY worker.py ./
CMD ["python", "-u", "worker.py"]
