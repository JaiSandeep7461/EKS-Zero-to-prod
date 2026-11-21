# syntax=docker/dockerfile:1

# Build and runtime use the same clean Python base and venv. This avoids
# carrying any vulnerable setuptools copy from a second/global Python install.
FROM --platform=linux/amd64 python:3.12-slim AS build
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --upgrade "setuptools==84.2.1" \
    && pip install --no-cache-dir --no-build-isolation . \
    && python -c "from importlib.metadata import version; assert version('setuptools') == '84.2.1', version('setuptools')"

# Runtime inherits from the patched build stage rather than starting from a
# fresh python:3.12-slim image with an independent global Python installation.
FROM build AS runtime
RUN groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
ENV PYTHONUNBUFFERED=1
COPY app ./app

USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os,urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8080')+'/healthz', timeout=2).status == 200 else 1)"]

CMD ["python", "-m", "app.main"]
