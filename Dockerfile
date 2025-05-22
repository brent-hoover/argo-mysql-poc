FROM python:3.9-slim

WORKDIR /app

# Install MySQL client and other required utilities
RUN apt-get update && apt-get install -y \
    mysql-client \
    bash \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Copy scripts and set permissions
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Set environment variable for scripts path
ENV SCRIPTS_PATH=/app/scripts

# Run the application
CMD ["python", "app.py"]