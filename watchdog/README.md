# minecraft-ecs-watchdog 
Fargate watchdog for Minecraft. Slight modification of the wonderful [doctorray117 / minecraft-ondemand / minecraft-ecsfargate-watchdog](https://github.com/doctorray117/minecraft-ondemand/tree/main/minecraft-ecsfargate-watchdog).

### Docker
```bash
docker build -t <image-name> .
```

Run the docker container with
```bash
docker run <image-name>
```
See additional options [here](https://docs.docker.com/engine/reference/run/#docker-run-reference).

#### Environment variables
##### Required
- `CLUSTER`: minecraft
- `SERVICE`: minecraft-server
- `DNS_ZONE`: Route 53 hosted zone ID from your checklist
- `SERVER_NAME`: The name associated with this server. Note that this server name is the same used in the domain `<SERVER_NAME>.mc.smarter-servers.net`

##### Optional
- `START_UP_MIN`: Number of minutes to wait for a connection after starting before terminating (default 10)
- `SHUT_DOWN_MIN`: Number of minutes to wait after the last client disconnects before terminating (default 20)


