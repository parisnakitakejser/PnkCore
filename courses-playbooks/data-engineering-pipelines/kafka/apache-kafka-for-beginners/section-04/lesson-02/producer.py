from kafka import KafkaProducer
import json

from settings import Settings

conf = Settings()

producer = KafkaProducer(
    bootstrap_servers=conf.kafka_bootstrap_servers,
    security_protocol=conf.kafka_security_protocol,
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)

with open("data/single-event.json", "r") as file:
    data = json.load(file)

# print your event out
print(f"event: {data}")
