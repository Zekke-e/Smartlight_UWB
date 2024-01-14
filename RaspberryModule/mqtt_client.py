# python3.9

import random
import gpiozero
from paho.mqtt import client as mqtt_client

led = gpiozero.LED(17)
broker = 'broker.emqx.io'
port = 1883
topic = "moj/top"
client_id = f'subscribe-{random.randint(0, 100)}'

def connect_mqtt() -> mqtt_client:
    def on_connect(client, userdata, flags, rc):
        if rc == 0:
            print("Connected to MQTT Broker!")
        else:
            print("Failed to connect, return code %d\n", rc)

    client = mqtt_client.Client(client_id)
    client.on_connect = on_connect
    client.connect(broker, port)
    return client


def subscribe(client: mqtt_client):
    def on_message(client, userdata, msg):
        message_received=str(msg.payload.decode())
	print(f"Received `{msg.payload.decode()}` from `{msg.topic}` topic")
        if message_recieved.find("Secure"):
            led.on()
            print("Connected to MQTT Broker!")
        else:
            led.off()
            print("off")


    client.subscribe(topic)
    client.on_message = on_message


def run():
    client = connect_mqtt()
    subscribe(client)
    client.loop_forever()


if __name__ == '__main__':
    run()

