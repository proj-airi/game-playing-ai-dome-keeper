"""Session metadata and the causal recording contract from ADR-0005."""

from pathlib import Path
from typing import Annotated, Any, Literal, Self, get_args

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


Task = Literal["pickup", "drop", "activate", "attack"]
Target = Literal["iron", "cobalt", "water", "gadget_chamber", "monster"]
Action = Literal["ui_up", "ui_down", "ui_left", "ui_right", "ui_select",
                 "keeper1_pickup", "keeper1_drop", "dome1_fire", "none"]
TASKS = list(get_args(Task))
TARGETS = list(get_args(Target))
ACTIONS = list(get_args(Action))
PAIRS = [(task, target) for task in TASKS[:2] for target in TARGETS[:3]] + [
    ("activate", "gadget_chamber"), ("attack", "monster")]
NonNegativeInt = Annotated[int, Field(ge=0)]
NonEmptyString = Annotated[str, Field(min_length=1)]
Metadata = Annotated[dict[str, Any], Field(min_length=1)]


class Record(BaseModel):
    model_config = ConfigDict(strict=True, extra="allow")


class Instruction(Record):
    task: Task
    target: Target

    @model_validator(mode="after")
    def supported_pair(self) -> Self:
        if (self.task, self.target) not in PAIRS:
            raise ValueError("unsupported task/target pair")
        return self


class Stamp(Record):
    order: NonNegativeInt
    time_us: NonNegativeInt
    physics_frame: NonNegativeInt


class Step(Stamp):
    frame_id: str | NonNegativeInt
    capture_order: NonNegativeInt
    decision_time_us: NonNegativeInt
    decision_physics_frame: NonNegativeInt
    held_action: Action
    next_action: Action
    video_frame: NonNegativeInt | None = None
    decision_video_frame: NonNegativeInt | None = None

    @field_validator("frame_id")
    @classmethod
    def frame_filename(cls, value: str | int) -> str | int:
        name = str(value)
        if not name or Path(name).name != name or name in (".", ".."):
            raise ValueError("invalid frame filename")
        return value

    @model_validator(mode="after")
    def capture_precedes_decision(self) -> Self:
        if (self.time_us > self.decision_time_us
                or self.physics_frame > self.decision_physics_frame
                or self.capture_order >= self.order):
            raise ValueError("future observation")
        return self


class Event(Stamp):
    kind: NonEmptyString
    action: Action


class Outcome(Stamp):
    status: Literal["success"]
    final_held_action: Literal["none"]


class Binding(Record):
    action: Action
    keycode: NonNegativeInt
    physical_keycode: NonNegativeInt


class Session(Record):
    schema_version: Annotated[int, Field(ge=1, le=1)]
    id: NonEmptyString
    scenario_id: NonEmptyString
    scenario: Metadata
    versions: Metadata
    bindings: Annotated[list[Binding], Field(min_length=1)]
    instruction: Instruction
    steps: Annotated[list[Step], Field(min_length=1)]
    events: list[Event]
    outcome: Outcome
    movie: str | None = None

    @model_validator(mode="after")
    def observation_cadence(self) -> Self:
        if self.steps[-1].next_action != "none":
            raise ValueError("terminal action must be none")
        frames = [str(step.frame_id) for step in self.steps]
        if len(set(frames)) != len(frames):
            raise ValueError("duplicate frame")
        if "movie" in self.model_fields_set:
            for step in self.steps:
                if (step.video_frame is None or step.decision_video_frame is None
                        or step.video_frame >= step.decision_video_frame):
                    raise ValueError("future video frame")
            for previous, step in zip(self.steps, self.steps[1:]):
                if step.video_frame - previous.video_frame != 3:
                    raise ValueError("missing video observation")
        for previous, step in zip(self.steps, self.steps[1:]):
            if (previous.order >= step.capture_order
                    or previous.decision_time_us > step.time_us):
                raise ValueError("observation ordering")
            if (step.decision_physics_frame - previous.decision_physics_frame != 6
                    or not 1 <= step.physics_frame - previous.physics_frame <= 12):
                raise ValueError("missing observation or invalid cadence")
        return self

    @model_validator(mode="after")
    def input_timeline(self) -> Self:
        for previous, event in zip(self.events, self.events[1:]):
            if event.order <= previous.order:
                raise ValueError("event ordering")
        timeline = [(event.order, event.time_us, event.physics_frame, event.kind, event.action)
                    for event in self.events]
        for step in self.steps:
            timeline.extend([
                (step.capture_order, step.time_us, step.physics_frame, "capture", step.held_action),
                (step.order, step.decision_time_us, step.decision_physics_frame,
                 "decision", step.next_action)])
        if self.outcome.order <= max(entry[0] for entry in timeline):
            raise ValueError("early outcome")
        timeline.append((self.outcome.order, self.outcome.time_us, self.outcome.physics_frame,
                         "outcome", self.outcome.final_held_action))
        held = "none"
        previous_order, previous_time, previous_physics = -1, -1, -1
        for order, time, physics, kind, action in sorted(timeline):
            if order <= previous_order or time < previous_time or physics < previous_physics:
                raise ValueError("inconsistent timeline")
            if kind == "input":
                held = action
            if kind in ("capture", "outcome") and action != held:
                raise ValueError("held action disagrees with input transitions")
            previous_order, previous_time, previous_physics = order, time, physics
        return self
