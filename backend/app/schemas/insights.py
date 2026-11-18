"""Request and response models for Smart Insights."""

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

InsightTitle = Annotated[str, Field(min_length=1, max_length=200)]


class SmartInsightRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    tasks: list[InsightTitle] = Field(default_factory=list, max_length=5)
    notes: list[InsightTitle] = Field(default_factory=list, max_length=5)


class SmartInsightResponse(BaseModel):
    insight: str = Field(min_length=1, max_length=500)
