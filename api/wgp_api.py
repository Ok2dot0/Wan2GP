"""
WanGP HTTP API Module

This module provides a RESTful HTTP API for WanGP video generation application.
It allows programmatic access to video generation, queue management, and file download.

Usage:
    Enable the API by running: python wgp.py --api
    The API will be available at http://localhost:7860/api/v1/
    
    API Documentation is available at http://localhost:7860/api/docs
"""

import os
import sys
import json
import uuid
import time
import base64
import threading
from pathlib import Path
from typing import Optional, List, Dict, Any, Union
from datetime import datetime
from io import BytesIO

from fastapi import FastAPI, HTTPException, BackgroundTasks, Query, File, UploadFile, Form
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from pydantic import BaseModel, Field
from PIL import Image


class ModelInfo(BaseModel):
    """Model information schema"""
    id: str = Field(..., description="Model identifier")
    name: str = Field(..., description="Human-readable model name")
    description: str = Field("", description="Model description")
    family: str = Field("", description="Model family (wan, hunyuan, ltxv, etc.)")
    is_i2v: bool = Field(False, description="Whether model supports image-to-video")
    is_t2v: bool = Field(False, description="Whether model supports text-to-video")
    visible: bool = Field(True, description="Whether model is visible in UI")


class GenerationRequest(BaseModel):
    """Video generation request schema"""
    prompt: str = Field(..., description="Text prompt for video generation")
    negative_prompt: str = Field("", description="Negative prompt")
    model_type: Optional[str] = Field(None, description="Model type to use")
    resolution: str = Field("832x480", description="Output resolution (e.g., '832x480', '1280x720')")
    video_length: int = Field(81, ge=1, le=1000, description="Number of frames to generate")
    num_inference_steps: int = Field(30, ge=1, le=100, description="Number of inference steps")
    guidance_scale: float = Field(5.0, ge=0.0, le=20.0, description="Guidance scale")
    seed: int = Field(-1, description="Random seed (-1 for random)")
    batch_size: int = Field(1, ge=1, le=10, description="Batch size for image generation")
    repeat_generation: int = Field(1, ge=1, le=10, description="Number of times to repeat generation")
    
    # Image inputs (base64 encoded)
    image_start: Optional[str] = Field(None, description="Start image (base64 encoded)")
    image_end: Optional[str] = Field(None, description="End image (base64 encoded)")
    image_refs: Optional[List[str]] = Field(None, description="Reference images (base64 encoded list)")
    
    # Advanced settings
    flow_shift: float = Field(5.0, description="Flow shift parameter")
    embedded_guidance_scale: float = Field(0.0, description="Embedded guidance scale")
    
    # Optional settings from model defaults
    use_model_defaults: bool = Field(True, description="Use model default settings for unspecified parameters")


class TaskInfo(BaseModel):
    """Task information schema"""
    id: int = Field(..., description="Task ID")
    prompt: str = Field(..., description="Task prompt")
    status: str = Field(..., description="Task status")
    length: int = Field(0, description="Video length in frames")
    steps: int = Field(0, description="Inference steps")
    position: int = Field(0, description="Position in queue")


class QueueStatus(BaseModel):
    """Queue status schema"""
    total_tasks: int = Field(..., description="Total number of tasks in queue")
    current_task_id: Optional[int] = Field(None, description="Currently processing task ID")
    tasks: List[TaskInfo] = Field(..., description="List of tasks")
    is_processing: bool = Field(False, description="Whether generation is in progress")


class GenerationStatus(BaseModel):
    """Generation status schema"""
    task_id: int = Field(..., description="Task ID")
    status: str = Field(..., description="Current status")
    progress: float = Field(0.0, ge=0.0, le=100.0, description="Progress percentage")
    current_step: int = Field(0, description="Current step")
    total_steps: int = Field(0, description="Total steps")
    eta_seconds: Optional[float] = Field(None, description="Estimated time remaining in seconds")


class GenerationResult(BaseModel):
    """Generation result schema"""
    task_id: int = Field(..., description="Task ID")
    status: str = Field(..., description="Final status")
    files: List[str] = Field(default_factory=list, description="List of generated file paths")
    generation_time_seconds: Optional[float] = Field(None, description="Total generation time")


class APIResponse(BaseModel):
    """Generic API response schema"""
    success: bool = Field(..., description="Whether the operation was successful")
    message: str = Field("", description="Response message")
    data: Optional[Any] = Field(None, description="Response data")


def create_api_router():
    """Create and return the FastAPI router for WanGP API"""
    from fastapi import APIRouter
    
    router = APIRouter(prefix="/api/v1", tags=["WanGP API"])
    
    # Store reference to wgp module globals
    _wgp_globals = {}
    
    def set_wgp_globals(wgp_module_globals: dict):
        """Set reference to wgp module globals"""
        _wgp_globals.update(wgp_module_globals)
    
    router.set_wgp_globals = set_wgp_globals
    
    def get_wgp():
        """Get wgp module globals"""
        if not _wgp_globals:
            raise HTTPException(status_code=503, detail="API not initialized. WGP module not available.")
        return _wgp_globals
    
    @router.get("/", response_model=APIResponse)
    async def api_root():
        """Get API information and status"""
        wgp = get_wgp()
        return APIResponse(
            success=True,
            message="WanGP API is running",
            data={
                "version": wgp.get("WanGP_version", "unknown"),
                "api_version": "1.0.0",
                "endpoints": {
                    "models": "/api/v1/models",
                    "generate": "/api/v1/generate",
                    "queue": "/api/v1/queue",
                    "status": "/api/v1/status/{task_id}",
                    "download": "/api/v1/download/{filename}",
                    "outputs": "/api/v1/outputs",
                }
            }
        )
    
    @router.get("/models", response_model=APIResponse)
    async def list_models():
        """Get list of available models"""
        wgp = get_wgp()
        
        displayed_model_types = wgp.get("displayed_model_types", [])
        get_model_def = wgp.get("get_model_def")
        get_model_name = wgp.get("get_model_name")
        get_model_family = wgp.get("get_model_family")
        test_class_i2v = wgp.get("test_class_i2v")
        test_class_t2v = wgp.get("test_class_t2v")
        
        models = []
        for model_type in displayed_model_types:
            model_def = get_model_def(model_type)
            if model_def:
                description_container = [""]
                name = get_model_name(model_type, description_container)
                models.append(ModelInfo(
                    id=model_type,
                    name=name,
                    description=description_container[0],
                    family=get_model_family(model_type, for_ui=True) if get_model_family else "",
                    is_i2v=test_class_i2v(model_type) if test_class_i2v else False,
                    is_t2v=test_class_t2v(model_type) if test_class_t2v else False,
                    visible=model_def.get("visible", True)
                ))
        
        return APIResponse(
            success=True,
            message=f"Found {len(models)} models",
            data={"models": [m.model_dump() for m in models]}
        )
    
    @router.get("/models/{model_type}", response_model=APIResponse)
    async def get_model_info(model_type: str):
        """Get detailed information about a specific model"""
        wgp = get_wgp()
        
        get_model_def = wgp.get("get_model_def")
        get_model_name = wgp.get("get_model_name")
        get_model_family = wgp.get("get_model_family")
        get_default_settings = wgp.get("get_default_settings")
        test_class_i2v = wgp.get("test_class_i2v")
        test_class_t2v = wgp.get("test_class_t2v")
        
        model_def = get_model_def(model_type)
        if not model_def:
            raise HTTPException(status_code=404, detail=f"Model '{model_type}' not found")
        
        description_container = [""]
        name = get_model_name(model_type, description_container)
        
        # Get default settings for this model
        default_settings = {}
        if get_default_settings:
            try:
                default_settings = get_default_settings(model_type)
                # Remove non-serializable items
                default_settings = {k: v for k, v in default_settings.items() 
                                   if isinstance(v, (str, int, float, bool, list, dict, type(None)))}
            except Exception:
                pass
        
        model_info = {
            "id": model_type,
            "name": name,
            "description": description_container[0],
            "family": get_model_family(model_type, for_ui=True) if get_model_family else "",
            "is_i2v": test_class_i2v(model_type) if test_class_i2v else False,
            "is_t2v": test_class_t2v(model_type) if test_class_t2v else False,
            "visible": model_def.get("visible", True),
            "default_settings": default_settings,
            "supported_features": {
                "sliding_window": model_def.get("sliding_window", False),
                "tea_cache": model_def.get("tea_cache", False),
                "mag_cache": model_def.get("mag_cache", False),
            }
        }
        
        return APIResponse(
            success=True,
            message=f"Model info for '{model_type}'",
            data=model_info
        )
    
    @router.get("/models/{model_type}/settings", response_model=APIResponse)
    async def get_model_default_settings(model_type: str):
        """Get default settings for a specific model"""
        wgp = get_wgp()
        
        get_model_def = wgp.get("get_model_def")
        get_default_settings = wgp.get("get_default_settings")
        
        model_def = get_model_def(model_type)
        if not model_def:
            raise HTTPException(status_code=404, detail=f"Model '{model_type}' not found")
        
        if not get_default_settings:
            raise HTTPException(status_code=503, detail="Settings retrieval not available")
        
        try:
            settings = get_default_settings(model_type)
            # Filter to serializable items only
            settings = {k: v for k, v in settings.items() 
                       if isinstance(v, (str, int, float, bool, list, dict, type(None)))}
            return APIResponse(
                success=True,
                message=f"Default settings for '{model_type}'",
                data=settings
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error getting settings: {str(e)}")
    
    @router.post("/generate", response_model=APIResponse)
    async def generate_video(request: GenerationRequest):
        """Submit a video generation request to the queue"""
        wgp = get_wgp()
        
        # Get required functions and variables
        get_model_def = wgp.get("get_model_def")
        get_default_settings = wgp.get("get_default_settings")
        add_video_task = wgp.get("add_video_task")
        transformer_type = wgp.get("transformer_type")
        
        # Use specified model or current model
        model_type = request.model_type or transformer_type
        if not model_type:
            raise HTTPException(status_code=400, detail="No model type specified and no default model set")
        
        model_def = get_model_def(model_type)
        if not model_def:
            raise HTTPException(status_code=404, detail=f"Model '{model_type}' not found")
        
        # Build inputs from request and defaults
        if request.use_model_defaults and get_default_settings:
            inputs = get_default_settings(model_type).copy()
        else:
            inputs = {}
        
        # Override with request values
        inputs.update({
            "prompt": request.prompt,
            "negative_prompt": request.negative_prompt,
            "resolution": request.resolution,
            "video_length": request.video_length,
            "num_inference_steps": request.num_inference_steps,
            "guidance_scale": request.guidance_scale,
            "seed": request.seed,
            "batch_size": request.batch_size,
            "repeat_generation": request.repeat_generation,
            "flow_shift": request.flow_shift,
            "embedded_guidance_scale": request.embedded_guidance_scale,
            "model_type": model_type,
            "model_filename": "",
            "mode": "",
        })
        
        # Process base64 images if provided
        if request.image_start:
            try:
                img_data = base64.b64decode(request.image_start)
                inputs["image_start"] = Image.open(BytesIO(img_data)).convert("RGB")
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Invalid image_start: {str(e)}")
        
        if request.image_end:
            try:
                img_data = base64.b64decode(request.image_end)
                inputs["image_end"] = Image.open(BytesIO(img_data)).convert("RGB")
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Invalid image_end: {str(e)}")
        
        if request.image_refs:
            try:
                inputs["image_refs"] = []
                for img_b64 in request.image_refs:
                    img_data = base64.b64decode(img_b64)
                    inputs["image_refs"].append(Image.open(BytesIO(img_data)).convert("RGB"))
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Invalid image_refs: {str(e)}")
        
        # Create API state for task tracking
        api_state = wgp.get("_api_state")
        if api_state is None:
            api_state = {"gen": {"queue": [], "file_list": [], "file_settings_list": [], 
                                "audio_file_list": [], "audio_file_settings_list": []}}
            wgp["_api_state"] = api_state
        
        inputs["state"] = api_state
        
        # Add task to queue
        try:
            task_id = wgp.get("task_id", 0) + 1
            wgp["task_id"] = task_id
            
            gen = api_state.get("gen", {})
            if "queue" not in gen:
                gen["queue"] = []
            
            # Simplified task adding for API
            task = {
                "id": task_id,
                "params": inputs.copy(),
                "plugin_data": {},
                "repeats": request.repeat_generation,
                "length": request.video_length,
                "steps": request.num_inference_steps,
                "prompt": request.prompt,
                "status": "queued",
                "created_at": datetime.now().isoformat(),
            }
            gen["queue"].append(task)
            
            return APIResponse(
                success=True,
                message=f"Generation task added to queue",
                data={
                    "task_id": task_id,
                    "position": len(gen["queue"]),
                    "estimated_wait": None  # Could calculate based on queue
                }
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error adding task: {str(e)}")
    
    @router.get("/queue", response_model=APIResponse)
    async def get_queue_status():
        """Get current queue status"""
        wgp = get_wgp()
        
        api_state = wgp.get("_api_state")
        if api_state is None:
            api_state = {"gen": {"queue": []}}
        gen = api_state.get("gen", {})
        queue = gen.get("queue", [])
        
        tasks = []
        for i, task in enumerate(queue):
            tasks.append(TaskInfo(
                id=task.get("id", 0),
                prompt=task.get("prompt", "")[:100],  # Truncate prompt
                status=task.get("status", "queued"),
                length=task.get("length", 0),
                steps=task.get("steps", 0),
                position=i + 1
            ))
        
        current_task_id = None
        if queue and len(queue) > 0:
            current_task_id = queue[0].get("id")
        
        status = QueueStatus(
            total_tasks=len(queue),
            current_task_id=current_task_id,
            tasks=tasks,
            is_processing=gen.get("in_progress", False)
        )
        
        return APIResponse(
            success=True,
            message=f"Queue has {len(queue)} tasks",
            data=status.model_dump()
        )
    
    @router.get("/status/{task_id}", response_model=APIResponse)
    async def get_task_status(task_id: int):
        """Get status of a specific task"""
        wgp = get_wgp()
        
        api_state = wgp.get("_api_state")
        if api_state is None:
            api_state = {"gen": {"queue": []}}
        gen = api_state.get("gen", {})
        queue = gen.get("queue", [])
        
        # Find task in queue
        task = next((t for t in queue if t.get("id") == task_id), None)
        
        if not task:
            # Check if it's completed
            completed_tasks = gen.get("completed_tasks", {})
            if task_id in completed_tasks:
                return APIResponse(
                    success=True,
                    message="Task completed",
                    data=completed_tasks[task_id]
                )
            raise HTTPException(status_code=404, detail=f"Task {task_id} not found")
        
        position = queue.index(task) + 1
        status = "processing" if position == 1 and gen.get("in_progress", False) else "queued"
        
        progress = gen.get("progress", 0) if status == "processing" else 0
        current_step = gen.get("current_step", 0) if status == "processing" else 0
        total_steps = task.get("steps", 0)
        
        return APIResponse(
            success=True,
            message=f"Task {task_id} status",
            data={
                "task_id": task_id,
                "status": status,
                "progress": progress,
                "current_step": current_step,
                "total_steps": total_steps,
                "position": position,
                "eta_seconds": None
            }
        )
    
    @router.delete("/queue/{task_id}", response_model=APIResponse)
    async def remove_task(task_id: int):
        """Remove a task from the queue"""
        wgp = get_wgp()
        
        api_state = wgp.get("_api_state")
        if api_state is None:
            api_state = {"gen": {"queue": []}}
        gen = api_state.get("gen", {})
        queue = gen.get("queue", [])
        
        # Find and remove task
        task_index = next((i for i, t in enumerate(queue) if t.get("id") == task_id), None)
        
        if task_index is None:
            raise HTTPException(status_code=404, detail=f"Task {task_id} not found in queue")
        
        # Don't allow removing currently processing task
        if task_index == 0 and gen.get("in_progress", False):
            raise HTTPException(status_code=400, detail="Cannot remove task that is currently processing")
        
        removed_task = queue.pop(task_index)
        
        return APIResponse(
            success=True,
            message=f"Task {task_id} removed from queue",
            data={"removed_task_id": task_id}
        )
    
    @router.delete("/queue", response_model=APIResponse)
    async def clear_queue():
        """Clear all tasks from the queue (except currently processing)"""
        wgp = get_wgp()
        
        api_state = wgp.get("_api_state")
        if api_state is None:
            api_state = {"gen": {"queue": []}}
        gen = api_state.get("gen", {})
        queue = gen.get("queue", [])
        
        # Keep the first task if it's processing
        if queue and gen.get("in_progress", False):
            removed_count = len(queue) - 1
            gen["queue"] = queue[:1]
        else:
            removed_count = len(queue)
            gen["queue"] = []
        
        return APIResponse(
            success=True,
            message=f"Cleared {removed_count} tasks from queue",
            data={"removed_count": removed_count}
        )
    
    @router.get("/outputs", response_model=APIResponse)
    async def list_outputs(
        limit: int = Query(50, ge=1, le=200, description="Maximum number of files to return"),
        offset: int = Query(0, ge=0, description="Offset for pagination"),
        file_type: Optional[str] = Query(None, description="Filter by type: 'video', 'image', 'audio'")
    ):
        """List generated output files"""
        wgp = get_wgp()
        
        save_path = wgp.get("save_path", "outputs")
        
        if not os.path.isdir(save_path):
            return APIResponse(
                success=True,
                message="No outputs found",
                data={"files": [], "total": 0}
            )
        
        # Get all files
        all_files = []
        for filename in os.listdir(save_path):
            filepath = os.path.join(save_path, filename)
            if os.path.isfile(filepath):
                ext = os.path.splitext(filename)[1].lower()
                
                # Determine file type
                if ext in ['.mp4', '.webm', '.avi', '.mov']:
                    ftype = 'video'
                elif ext in ['.png', '.jpg', '.jpeg', '.webp']:
                    ftype = 'image'
                elif ext in ['.wav', '.mp3', '.ogg', '.flac']:
                    ftype = 'audio'
                else:
                    ftype = 'other'
                
                # Apply filter
                if file_type and ftype != file_type:
                    continue
                
                stat = os.stat(filepath)
                all_files.append({
                    "filename": filename,
                    "type": ftype,
                    "size_bytes": stat.st_size,
                    "created_at": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                    "modified_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                })
        
        # Sort by modification time (newest first)
        all_files.sort(key=lambda x: x["modified_at"], reverse=True)
        
        # Apply pagination
        total = len(all_files)
        files = all_files[offset:offset + limit]
        
        return APIResponse(
            success=True,
            message=f"Found {total} files",
            data={
                "files": files,
                "total": total,
                "limit": limit,
                "offset": offset
            }
        )
    
    @router.get("/download/{filename}")
    async def download_file(filename: str):
        """Download a generated file"""
        wgp = get_wgp()
        
        save_path = wgp.get("save_path", "outputs")
        
        # Security: prevent path traversal
        filename = os.path.basename(filename)
        filepath = os.path.join(save_path, filename)
        
        if not os.path.isfile(filepath):
            raise HTTPException(status_code=404, detail=f"File '{filename}' not found")
        
        # Determine media type
        ext = os.path.splitext(filename)[1].lower()
        media_types = {
            '.mp4': 'video/mp4',
            '.webm': 'video/webm',
            '.avi': 'video/x-msvideo',
            '.mov': 'video/quicktime',
            '.png': 'image/png',
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.webp': 'image/webp',
            '.wav': 'audio/wav',
            '.mp3': 'audio/mpeg',
            '.ogg': 'audio/ogg',
            '.flac': 'audio/flac',
        }
        media_type = media_types.get(ext, 'application/octet-stream')
        
        return FileResponse(
            filepath,
            media_type=media_type,
            filename=filename
        )
    
    @router.get("/preview/{filename}")
    async def preview_file(filename: str, width: int = Query(320, ge=32, le=1920)):
        """Get a preview/thumbnail of a file (for images and videos)"""
        wgp = get_wgp()
        
        save_path = wgp.get("save_path", "outputs")
        
        # Security: prevent path traversal
        filename = os.path.basename(filename)
        filepath = os.path.join(save_path, filename)
        
        if not os.path.isfile(filepath):
            raise HTTPException(status_code=404, detail=f"File '{filename}' not found")
        
        ext = os.path.splitext(filename)[1].lower()
        
        try:
            if ext in ['.png', '.jpg', '.jpeg', '.webp']:
                # Generate image thumbnail
                img = Image.open(filepath)
                aspect = img.height / img.width
                new_height = int(width * aspect)
                img_thumb = img.resize((width, new_height), Image.Resampling.LANCZOS)
                
                buffer = BytesIO()
                img_thumb.save(buffer, format='JPEG', quality=80)
                buffer.seek(0)
                
                return StreamingResponse(buffer, media_type="image/jpeg")
            
            elif ext in ['.mp4', '.webm', '.avi', '.mov']:
                # Extract first frame as preview
                try:
                    from shared.utils.utils import get_video_frame
                    frame = get_video_frame(filepath, 0)
                    if frame:
                        aspect = frame.height / frame.width
                        new_height = int(width * aspect)
                        frame_thumb = frame.resize((width, new_height), Image.Resampling.LANCZOS)
                        
                        buffer = BytesIO()
                        frame_thumb.save(buffer, format='JPEG', quality=80)
                        buffer.seek(0)
                        
                        return StreamingResponse(buffer, media_type="image/jpeg")
                except Exception:
                    pass
                
                raise HTTPException(status_code=400, detail="Could not generate video preview")
            
            else:
                raise HTTPException(status_code=400, detail="Preview not available for this file type")
                
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error generating preview: {str(e)}")
    
    @router.get("/config", response_model=APIResponse)
    async def get_config():
        """Get current server configuration (non-sensitive values only)"""
        wgp = get_wgp()
        
        server_config = wgp.get("server_config", {})
        
        # Return only safe configuration values
        safe_config = {
            "save_path": server_config.get("save_path", "outputs"),
            "attention_mode": server_config.get("attention_mode", "auto"),
            "profile": server_config.get("profile", 1),
            "transformer_quantization": server_config.get("transformer_quantization", "int8"),
            "vae_config": server_config.get("vae_config", 0),
            "mmaudio_enabled": server_config.get("mmaudio_enabled", 0),
        }
        
        return APIResponse(
            success=True,
            message="Server configuration",
            data=safe_config
        )
    
    @router.get("/health")
    async def health_check():
        """Health check endpoint"""
        return {"status": "healthy", "timestamp": datetime.now().isoformat()}
    
    return router


def mount_api(app, wgp_globals: dict):
    """Mount the API router to a FastAPI/Gradio app"""
    router = create_api_router()
    router.set_wgp_globals(wgp_globals)
    
    # Mount at /api/v1
    app.include_router(router)
    
    # Add OpenAPI docs
    from fastapi.openapi.docs import get_swagger_ui_html, get_redoc_html
    from fastapi.openapi.utils import get_openapi
    
    @app.get("/api/docs", include_in_schema=False)
    async def api_docs():
        return get_swagger_ui_html(
            openapi_url="/api/openapi.json",
            title="WanGP API Documentation"
        )
    
    @app.get("/api/redoc", include_in_schema=False)
    async def api_redoc():
        return get_redoc_html(
            openapi_url="/api/openapi.json",
            title="WanGP API Documentation"
        )
    
    @app.get("/api/openapi.json", include_in_schema=False)
    async def api_openapi():
        return get_openapi(
            title="WanGP API",
            version="1.0.0",
            description="HTTP API for WanGP video generation application",
            routes=app.routes
        )
    
    return app
