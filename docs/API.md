# WanGP HTTP API Documentation

WanGP provides a RESTful HTTP API for programmatic access to video generation and related features.

## Enabling the API

### With Gradio UI (default)
```bash
python wgp.py --api
```
This runs the full Gradio interface with the API mounted at `/api/v1/`.

### API-Only Mode
```bash
python wgp.py --api-only
```
This runs only the API server without the Gradio UI, useful for headless deployments.

## API Base URL

- **With Gradio UI**: `http://localhost:7860/api/v1/`
- **API-Only Mode**: `http://localhost:7860/api/v1/`

## Interactive Documentation

When the API is enabled, interactive documentation is available at:
- **Swagger UI**: `http://localhost:7860/api/docs`
- **ReDoc**: `http://localhost:7860/api/redoc`
- **OpenAPI JSON**: `http://localhost:7860/api/openapi.json`

## Authentication

Currently, the API does not require authentication. It's recommended to run behind a reverse proxy with authentication for production use.

## Endpoints

### General

#### GET /api/v1/
Get API information and status.

**Response:**
```json
{
    "success": true,
    "message": "WanGP API is running",
    "data": {
        "version": "9.62",
        "api_version": "1.0.0",
        "endpoints": {...}
    }
}
```

#### GET /api/v1/health
Health check endpoint.

**Response:**
```json
{
    "status": "healthy",
    "timestamp": "2025-01-15T10:30:00.000Z"
}
```

### Models

#### GET /api/v1/models
List all available models.

**Response:**
```json
{
    "success": true,
    "message": "Found 50 models",
    "data": {
        "models": [
            {
                "id": "wan_t2v_14B",
                "name": "Wan 2.1 Text to Video 14B",
                "description": "High quality text to video generation",
                "family": "wan",
                "is_i2v": false,
                "is_t2v": true,
                "visible": true
            }
        ]
    }
}
```

#### GET /api/v1/models/{model_type}
Get detailed information about a specific model.

**Parameters:**
- `model_type` (path): Model identifier (e.g., `wan_t2v_14B`)

**Response:**
```json
{
    "success": true,
    "message": "Model info for 'wan_t2v_14B'",
    "data": {
        "id": "wan_t2v_14B",
        "name": "Wan 2.1 Text to Video 14B",
        "description": "...",
        "default_settings": {...},
        "supported_features": {
            "sliding_window": true,
            "tea_cache": true,
            "mag_cache": false
        }
    }
}
```

#### GET /api/v1/models/{model_type}/settings
Get default settings for a specific model.

**Response:**
```json
{
    "success": true,
    "message": "Default settings for 'wan_t2v_14B'",
    "data": {
        "prompt": "...",
        "resolution": "832x480",
        "video_length": 81,
        "num_inference_steps": 30,
        "guidance_scale": 5.0,
        "flow_shift": 5.0
    }
}
```

### Generation

#### POST /api/v1/generate
Submit a video generation request.

**Request Body:**
```json
{
    "prompt": "A beautiful sunset over the ocean",
    "negative_prompt": "",
    "model_type": "wan_t2v_14B",
    "resolution": "832x480",
    "video_length": 81,
    "num_inference_steps": 30,
    "guidance_scale": 5.0,
    "seed": -1,
    "batch_size": 1,
    "repeat_generation": 1,
    "flow_shift": 5.0,
    "use_model_defaults": true
}
```

**Optional Image Inputs (base64 encoded):**
```json
{
    "prompt": "Animate this image",
    "image_start": "base64_encoded_image_data...",
    "image_end": "base64_encoded_image_data...",
    "image_refs": ["base64_encoded_image_data..."]
}
```

**Response:**
```json
{
    "success": true,
    "message": "Generation task added to queue",
    "data": {
        "task_id": 123,
        "position": 1,
        "estimated_wait": null
    }
}
```

### Queue Management

#### GET /api/v1/queue
Get current queue status.

**Response:**
```json
{
    "success": true,
    "message": "Queue has 3 tasks",
    "data": {
        "total_tasks": 3,
        "current_task_id": 121,
        "is_processing": true,
        "tasks": [
            {
                "id": 121,
                "prompt": "A beautiful sunset...",
                "status": "processing",
                "length": 81,
                "steps": 30,
                "position": 1
            }
        ]
    }
}
```

#### GET /api/v1/status/{task_id}
Get status of a specific task.

**Parameters:**
- `task_id` (path): Task ID

**Response:**
```json
{
    "success": true,
    "message": "Task 121 status",
    "data": {
        "task_id": 121,
        "status": "processing",
        "progress": 45.5,
        "current_step": 14,
        "total_steps": 30,
        "position": 1,
        "eta_seconds": null
    }
}
```

#### DELETE /api/v1/queue/{task_id}
Remove a task from the queue.

**Response:**
```json
{
    "success": true,
    "message": "Task 122 removed from queue",
    "data": {
        "removed_task_id": 122
    }
}
```

#### DELETE /api/v1/queue
Clear all tasks from the queue (except currently processing).

**Response:**
```json
{
    "success": true,
    "message": "Cleared 5 tasks from queue",
    "data": {
        "removed_count": 5
    }
}
```

### Output Files

#### GET /api/v1/outputs
List generated output files.

**Query Parameters:**
- `limit` (int, default: 50): Maximum files to return (1-200)
- `offset` (int, default: 0): Pagination offset
- `file_type` (string, optional): Filter by type (`video`, `image`, `audio`)

**Response:**
```json
{
    "success": true,
    "message": "Found 100 files",
    "data": {
        "files": [
            {
                "filename": "video_001.mp4",
                "type": "video",
                "size_bytes": 15728640,
                "created_at": "2025-01-15T10:30:00.000Z",
                "modified_at": "2025-01-15T10:35:00.000Z"
            }
        ],
        "total": 100,
        "limit": 50,
        "offset": 0
    }
}
```

#### GET /api/v1/download/{filename}
Download a generated file.

**Parameters:**
- `filename` (path): Filename to download

**Response:** Binary file data with appropriate Content-Type header.

#### GET /api/v1/preview/{filename}
Get a preview/thumbnail of an image or video.

**Parameters:**
- `filename` (path): Filename to preview
- `width` (query, default: 320): Thumbnail width (32-1920)

**Response:** JPEG image data.

### Configuration

#### GET /api/v1/config
Get current server configuration (non-sensitive values only).

**Response:**
```json
{
    "success": true,
    "message": "Server configuration",
    "data": {
        "save_path": "outputs",
        "attention_mode": "sage",
        "profile": 1,
        "transformer_quantization": "int8",
        "vae_config": 0,
        "mmaudio_enabled": 0
    }
}
```

## Error Handling

All errors follow this format:
```json
{
    "detail": "Error message describing what went wrong"
}
```

Common HTTP status codes:
- `200`: Success
- `400`: Bad request (invalid parameters)
- `404`: Resource not found
- `500`: Internal server error
- `503`: Service unavailable (API not initialized)

## Examples

### Python Example
```python
import requests
import base64

API_BASE = "http://localhost:7860/api/v1"

# List models
response = requests.get(f"{API_BASE}/models")
models = response.json()["data"]["models"]
print(f"Available models: {len(models)}")

# Generate video from text
response = requests.post(f"{API_BASE}/generate", json={
    "prompt": "A cat playing piano in a jazz club",
    "video_length": 81,
    "num_inference_steps": 30
})
task_id = response.json()["data"]["task_id"]
print(f"Task created: {task_id}")

# Check status
response = requests.get(f"{API_BASE}/status/{task_id}")
print(response.json())

# Download output (when complete)
response = requests.get(f"{API_BASE}/outputs")
files = response.json()["data"]["files"]
if files:
    latest = files[0]["filename"]
    response = requests.get(f"{API_BASE}/download/{latest}")
    with open(f"downloaded_{latest}", "wb") as f:
        f.write(response.content)
```

### Image-to-Video Example
```python
import requests
import base64

API_BASE = "http://localhost:7860/api/v1"

# Load and encode image
with open("my_image.png", "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode()

# Generate video from image
response = requests.post(f"{API_BASE}/generate", json={
    "prompt": "The person in the image starts dancing",
    "model_type": "wan_i2v_14B",
    "image_start": image_b64,
    "video_length": 81
})
print(response.json())
```

### cURL Examples
```bash
# List models
curl http://localhost:7860/api/v1/models

# Generate video
curl -X POST http://localhost:7860/api/v1/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "A beautiful mountain landscape"}'

# Get queue status
curl http://localhost:7860/api/v1/queue

# Download file
curl -O http://localhost:7860/api/v1/download/video_001.mp4
```

## Rate Limiting

There is no built-in rate limiting. For production deployments, it's recommended to use a reverse proxy (nginx, caddy, etc.) to implement rate limiting.

## CORS

CORS is not enabled by default. If you need to access the API from a web browser on a different origin, you'll need to configure CORS through a reverse proxy or modify the API configuration.
