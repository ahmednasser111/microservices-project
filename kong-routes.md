# Create service

curl -X POST http://localhost:8001/services \
 --data name=auth-service \
 --data url=http://localhost:3001

# Create route

curl -X POST http://localhost:8001/services/auth-service/routes \
 --data name=auth-route \
 --data paths[]=/auth \
 --data strip_path=true

# Create service

curl -X POST http://localhost:8001/services \
 --data name=chat-service \
 --data url=http://localhost:3002

# Create route

curl -X POST http://localhost:8001/services/chat-service/routes \
 --data name=chat-route \
 --data paths[]=/chat \
 --data strip_path=true
