from kafka import KafkaProducer
import json

from settings import Settings

conf = Settings()

producer = KafkaProducer(
    bootstrap_servers=conf.kafka_bootstrap_servers,
    security_protocol=conf.kafka_security_protocol,
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)

with open("data/bulk-events.json", "r") as file:
    data = json.load(file)

for event in data:
    # print your event out
    print(f"event: {event}")

    producer.send(
        topic=conf.topic,
        value=event,
        key=event["guid"].encode("utf-8"),
        headers=[
            ("isActive", bytes(str(event["isActive"]), encoding="utf-8")),
        ],
    )
producer.flush()
