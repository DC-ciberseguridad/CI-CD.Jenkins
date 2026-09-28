import os
import time
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel

app = FastAPI(
    title="DevOps Enterprise API - Lab #10",
    description="API REST de producción para integración con Jenkins CI/CD y Kubernetes",
    version="1.0.0"
)

# Simulamos la hora de inicio de la aplicación
START_TIME = time.time()

class MetricsResponse(BaseModel):
    environment: str
    status: str
    uptime_seconds: float

class Task(BaseModel):
    id: int
    title: str
    completed: bool = False

# Base de datos en memoria para pruebas
db_tasks = [
    {"id": 1, "title": "Aprender Jenkins as Code", "completed": True},
    {"id": 2, "title": "Configurar Agentes en Kubernetes", "completed": True},
    {"id": 3, "title": "Desplegar API en AWS ECR", "completed": False},
]

@app.get("/", tags=["General"])
def read_root():
    """Endpoint raíz que retorna un mensaje de bienvenida y el entorno activo."""
    env = os.getenv("ENVIRONMENT", "development")
    return {
        "message": "Bienvenido al laboratorio #10 de DevOps & CI/CD",
        "environment": env,
        "docs": "/docs"
    }

@app.get("/health", status_code=status.HTTP_200_OK, tags=["Health Checks"])
def health_check():
    """Liveness Probe: Indica si la aplicación está viva y respondiendo."""
    return {"status": "healthy", "timestamp": time.time()}

@app.get("/ready", status_code=status.HTTP_200_OK, tags=["Health Checks"])
def readiness_check():
    """Readiness Probe: Indica si la aplicación está lista para recibir tráfico."""
    # Podrías agregar verificaciones de conexión a DB o servicios externos aquí
    return {"status": "ready", "database_connected": True}

@app.get("/api/v1/metrics", response_model=MetricsResponse, tags=["Business Metrics"])
def get_metrics():
    """Retorna métricas operativas del servicio."""
    env = os.getenv("ENVIRONMENT", "development")
    uptime = time.time() - START_TIME
    return MetricsResponse(
        environment=env,
        status="operational",
        uptime_seconds=round(uptime, 2)
    )

@app.get("/api/v1/tasks", tags=["Business Logic"])
def get_tasks():
    """Listado de tareas registradas."""
    return {"tasks": db_tasks, "total": len(db_tasks)}

@app.post("/api/v1/tasks", status_code=status.HTTP_201_CREATED, tags=["Business Logic"])
def create_task(task: Task):
    """Crea una nueva tarea en la base de datos."""
    for t in db_tasks:
        if t["id"] == task.id:
            raise HTTPException(
                status_code=400, 
                detail=f"La tarea con ID {task.id} ya existe."
            )
    db_tasks.append(task.model_dump())
    return {"message": "Tarea creada exitosamente", "task": task}