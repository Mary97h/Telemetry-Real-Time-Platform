import os
KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS","localhost:9092")
POSTGRES_HOST = os.getenv("POSTGRES_HOST","localhost")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT","5432"))
POSTGRES_USER = os.getenv("POSTGRES_USER","telemetry")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD","telemetry123")
POSTGRES_DB = os.getenv("POSTGRES_DB","telemetry_db")
REDIS_HOST = os.getenv("REDIS_HOST","localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT","6379"))
