# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 python:3.12-slim AS build
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY pyproject.toml ./
COPY app ./app
# Pin setuptools in the build environment itself. The PEP 517 isolated build
# environment otherwise bootstraps its own copy and can leave the base-image
# setuptools (70.3.0) in the image scanned by Trivy.
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --upgrade "setuptools==78.1.1" \
    && pip install --no-cache-dir --no-build-isolation . \
    && python -c "import setuptools; assert setuptools.__version__ == '78.1.1', setuptools.__version__"

FROM --platform=linux/amd64 python:3.12-slim AS runtime
# Pull in all available Debian security updates so the runtime image does not
# ship fixable OS-package CVEs (the Trivy image gate in ci.yml/pr-checks
# blocks on HIGH/CRITICAL). Anything left after this is genuinely unfixable
# (no upstream Debian patch yet) and is enumerated, with justification, in
# the repo-root .trivyignore.
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y --purge autoremove \
    && rm -rf /var/lib/apt/lists/*
# Trivy scans the entire final image, including globally installed Python
# packaging tools in /usr/local/lib/python3.12/site-packages (not just the
# application's /opt/venv). Upgrade these in the runtime stage as well as the
# builder stage so vulnerable base-image copies cannot remain in the image.
RUN python -m pip install --no-cache-dir --upgrade \
      "pip" \
      "setuptools==78.1.1" \
      "jaraco.context>=6.1.0" \
      "wheel>=0.46.2" \
    && python -c "import setuptools, jaraco.context, wheel; assert setuptools.__version__ == '78.1.1', setuptools.__version__; assert tuple(map(int, jaraco.context.__version__.split('.'))) >= (6, 1, 0), jaraco.context.__version__; assert tuple(map(int, wheel.__version__.split('.'))) >= (0, 46, 2), wheel.__version__"
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
