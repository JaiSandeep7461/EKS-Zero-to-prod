# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 python:3.12-slim AS build
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY pyproject.toml ./
COPY app ./app
# Use a current setuptools release whose vendored packaging dependencies are
# patched. Trivy scans vendored METADATA as well as top-level packages.
RUN find /opt/venv/lib/python3.12/site-packages -maxdepth 1 -name 'setuptools*' -exec rm -rf {} + \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --upgrade "setuptools==84.2.1" \
    && pip install --no-cache-dir --no-build-isolation . \
    && python -c "import setuptools; assert setuptools.__version__ == '84.2.1', setuptools.__version__"

FROM --platform=linux/amd64 python:3.12-slim AS runtime
# Pull in all available Debian security updates so the runtime image does not
# ship fixable OS-package CVEs (the Trivy image gate in ci.yml/pr-checks
# blocks on HIGH/CRITICAL). Anything left after this is genuinely unfixable
# (no upstream Debian patch yet) and is enumerated, with justification, in
# the repo-root .trivyignore.
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y --purge autoremove \
    && apt-get purge -y python3-setuptools \
    && rm -rf /var/lib/apt/lists/*
# The application runs from /opt/venv. Do not install a second global
# setuptools copy in the runtime image: Trivy scans every Python installation,
# and the base image can contain a stale setuptools distribution outside pip's
# active environment. Remove global setuptools artifacts defensively; the
# patched setuptools 84.2.1 in /opt/venv is copied below.
RUN rm -rf \
      /usr/local/lib/python3.12/site-packages/setuptools* \
      /usr/local/lib/python3.12/site-packages/pkg_resources* \
      /usr/lib/python3/dist-packages/setuptools* \
      /usr/lib/python3/dist-packages/pkg_resources* \
    && python -m pip install --no-cache-dir --upgrade pip \
    && python -c "import importlib.util; assert importlib.util.find_spec('setuptools') is None"
RUN groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1
COPY --from=build /opt/venv /opt/venv
COPY app ./app

USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os,urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8080')+'/healthz', timeout=2).status == 200 else 1)"]

CMD ["python", "-m", "app.main"]
