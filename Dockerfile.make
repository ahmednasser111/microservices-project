FROM alpine:latest

# Install make and bash
RUN apk add --no-cache make bash

# Set work directory inside container
WORKDIR /app

# Copy everything into container
COPY . .

# Default command to run make
CMD ["make"]
