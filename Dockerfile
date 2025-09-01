FROM python:3.12-slim

WORKDIR /app

# No dependencies for this sample; copy only the package
COPY sample_app/ /app/sample_app/

# Ensure UTF-8 and no pyc files
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

ENTRYPOINT ["python", "-m", "sample_app"]
