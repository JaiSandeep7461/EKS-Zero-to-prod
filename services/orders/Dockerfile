# syntax=docker/dockerfile:1

# Build dependencies and setuptools are intentionally confined to this stage.
FROM --platform=linux/amd64 python:3.12-alpine AS build
RUN apk update && apk upgrade
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --upgrade "setuptools==84.2.1" \
    && pip install --no-cache-dir --no-build-isolation . \
    && python -c "from importlib.metadata import version; assert version('setuptools') == '84.2.1', version('setuptools')"

# Start runtime from a fresh base image. Copy only the app environment, then
# remove build-only packaging tools from the copied venv. The app itself does
# not need setuptools, pip, or wheel at runtime.
FROM --platform=linux/amd64 python:3.12-alpine AS runtime
RUN apk update && apk upgrade
RUN addgroup -S app && adduser -S -G app app
WORKDIR /app
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1
COPY --from=build /opt/venv /opt/venv
RUN /opt/venv/bin/python -m pip uninstall -y setuptools wheel pip \
    && rm -rf /opt/venv/lib/python3.12/site-packages/pkg_resources* \
    && /opt/venv/bin/python -c "import importlib.util; assert importlib.util.find_spec('setuptools') is None; assert importlib.util.find_spec('pip') is None"
COPY app ./app

USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os,urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8080')+'/healthz', timeout=2).status == 200 else 1)"]

CMD ["python", "-m", "app.main"]
