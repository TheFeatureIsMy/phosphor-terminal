"""
Common schemas for API responses
"""
from typing import Dict,  Optional,  Any, Generic, TypeVar
from pydantic import BaseModel
T = TypeVar("T")
class SuccessResponse(BaseModel, Generic[T]):
    """Standard success response"""
    success: bool = True
    data: T
    message: str = "OK"
class ErrorResponse(BaseModel):
    """Standard error response"""
    success: bool = False
    error: str
    message: str
    details: Optional[Dict[str, Any]] = None
class PaginatedResponse(BaseModel, Generic[T]):
    """Paginated response"""
    items: list[T]
    total: int
    page: int
    page_size: int
    pages: int
class MessageResponse(BaseModel):
    """Simple message response"""
    message: str
