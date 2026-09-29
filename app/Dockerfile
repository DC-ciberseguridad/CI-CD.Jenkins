# ==========================================
# STAGE 1: Builder (Instalación de dependencias)
# ==========================================
FROM python:3.11-slim AS builder

WORKDIR /app

# Instalar herramientas de compilación
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copiar e instalar dependencias en una carpeta temporal
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ==========================================
# STAGE 2: Runner (Imagen final de producción)
# ==========================================
FROM python:3.11-slim AS runner

WORKDIR /app

# Crear usuario y grupo sin privilegios de root por buenas prácticas de seguridad
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/sh -m appuser

# Copiar dependencias instaladas desde la etapa de builder
COPY --from=builder /install /usr/local

# Copiar el código fuente de la aplicación
COPY app/ /app/app/

# Asignar permisos al usuario no privilegiado
RUN chown -R appuser:appgroup /app

# Cambiar al usuario no-root
USER appuser

# Variables de entorno por defecto
ENV ENVIRONMENT=production \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Exponer el puerto de la aplicación
EXPOSE 8000

# Endpoint de comprobación básica dentro del contenedor
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Comando para ejecutar la API con Uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]