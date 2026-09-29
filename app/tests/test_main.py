import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_read_root():
    """Verifica que el endpoint raíz responda 200 OK con la estructura correcta."""
    response = client.get("/")
    assert response.status_code == 200
    json_data = response.json()
    assert "message" in json_data
    assert "environment" in json_data

def test_health_check():
    """Verifica el Liveness Probe del servicio."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_readiness_check():
    """Verifica el Readiness Probe del servicio."""
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"
    assert response.json()["database_connected"] is True

def test_get_metrics():
    """Verifica que el endpoint de métricas devuelva los tipos de datos requeridos."""
    response = client.get("/api/v1/metrics")
    assert response.status_code == 200
    json_data = response.json()
    assert json_data["status"] == "operational"
    assert json_data["uptime_seconds"] >= 0

def test_get_tasks():
    """Verifica la obtención de tareas registradas."""
    response = client.get("/api/v1/tasks")
    assert response.status_code == 200
    assert "tasks" in response.json()
    assert response.json()["total"] > 0

def test_create_task_success():
    """Verifica la creación exitosa de una nueva tarea."""
    new_task = {"id": 99, "title": "Probar CI con Pytest en Jenkins", "completed": False}
    response = client.post("/api/v1/tasks", json=new_task)
    assert response.status_code == 201
    assert response.json()["task"]["id"] == 99

def test_create_duplicate_task_fails():
    """Verifica que la API rechace tareas con IDs duplicados."""
    duplicate_task = {"id": 1, "title": "Tarea Duplicada", "completed": False}
    response = client.post("/api/v1/tasks", json=duplicate_task)
    assert response.status_code == 400