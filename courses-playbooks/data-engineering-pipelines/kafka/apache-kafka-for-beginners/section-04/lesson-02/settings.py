from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    kafka_bootstrap_servers: str = "localhost:29092"
    kafka_security_protocol: str = "PLAINTEXT"

    topic: str = "apache-kafka-for-beginners"
