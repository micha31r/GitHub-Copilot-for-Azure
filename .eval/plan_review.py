"""Infrastructure plan evaluator for .azure/infrastructure-plan.json.

Usage:
  python .eval/plan_review.py --root .azure

Reads the infrastructure-plan.json artifact produced by azure-infra-planner
from the specified --root directory (default: .azure/) and produces a
plan_review_result.json with LLM-based evaluation scores.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import logging
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional

import sys, os

# Ensure project src/ directory is on sys.path so we can import aoai_client when
# this script is executed directly
_THIS_FILE = Path(__file__).resolve()
_REPO_ROOT = _THIS_FILE.parents[1]  # repo root (one level up from .eval/)
_SRC_DIR = _REPO_ROOT / "src"
if str(_SRC_DIR) not in sys.path:
	sys.path.insert(0, str(_SRC_DIR))

try:  # noqa: E722
	from aoai_client import get_aoai_client  # type: ignore
except Exception as _imp_err:  # Fallback: disable LLM if import fails
	get_aoai_client = None  # type: ignore


# ---------------- Logging Setup ----------------
logger = logging.getLogger("plan_review")
if not logger.handlers:
	handler = logging.StreamHandler()
	handler.setFormatter(logging.Formatter("%(asctime)s | %(levelname)s | %(message)s"))
	logger.addHandler(handler)
logger.setLevel(logging.INFO)


INFRA_PLAN_FILENAME = "infrastructure-plan.json"
OUTPUT_FILENAME = "plan_review_result.json"
PROMPT_FILE = Path(__file__).with_name("plan_review.txt")


@dataclass
class CheckResult:
	name: str
	passed: bool
	details: str


@dataclass
class PlanReview:
	case_id: str
	goal: str | None
	checks: List[CheckResult]
	score: float
	overall_passed: bool
	notes: str
	# Extended fields from LLM evaluation (optional)
	risks: Optional[List[str]] = None
	evaluation_raw: Optional[Dict[str, Any]] = None
	correctionsRecommended: Optional[List[str]] = None
	deployment_risks: Optional[List[str]] = None

	def to_json(self) -> Dict[str, Any]:
		base = {
			"case_id": self.case_id,
			"goal": self.goal,
			"score": round(self.score, 3),
			"overall_passed": self.overall_passed,
			"checks": [asdict(c) for c in self.checks],
			"notes": self.notes,
		}
		# Attach LLM evaluation fields if present
		if self.evaluation_raw is not None:
			base["evaluation"] = self.evaluation_raw
		return base


def load_plan(path: Path) -> Dict[str, Any]:
	"""Load infrastructure plan from .azure/infrastructure-plan.json."""
	with path.open("r", encoding="utf-8") as f:
		data = json.load(f)

	# Validate expected structure
	if not isinstance(data, dict):
		raise ValueError(f"Expected JSON object in {path}, got {type(data).__name__}")

	# Must have plan.resources
	plan = data.get("plan", {})
	if not plan or not plan.get("resources"):
		raise ValueError(f"No plan.resources found in {path}")

	return data


async def evaluate_plan_llm(plan: Dict[str, Any], case_id: str, model: str, base_prompt: str) -> PlanReview:
	"""Call Azure OpenAI to evaluate the infra plan returning structured PlanReview."""
	goal = plan.get("inputs", {}).get("userGoal")
	logger.debug(f"Evaluating plan for case {case_id}; goal snippet: {str(goal)[:80]}")
	plan_str = json.dumps(plan, indent=2)
	user_message = (
		"Evaluate the following Azure infrastructure plan JSON. Return ONLY the specified JSON schema.\n"
		"\nPLAN:\n" + plan_str
	)
	if get_aoai_client is None:  # type: ignore
		logger.warning("LLM client unavailable; returning stub result")
		return PlanReview(
			case_id=case_id,
			goal=goal,
			checks=[],
			score=0.0,
			overall_passed=False,
			notes="LLM client unavailable (aoai_client import failed).",
		)
	client = await get_aoai_client()  # type: ignore
	logger.debug(f"Calling model '{model}' for case {case_id}")
	messages = [
		{"role": "system", "content": base_prompt},
		{"role": "user", "content": user_message},
	]
	try:
		resp = await client.responses.create(model=model, input=messages)
		text_chunks: List[str] = []
		if hasattr(resp, "output"):
			for item in getattr(resp, "output", []) or []:
				for c in getattr(item, "content", []) or []:
					ct = getattr(c, "type", None)
					val = getattr(c, "text", None) or getattr(c, "output_text", None)
					if ct in ("text", "output_text") and val:
						text_chunks.append(val)
		raw_output = "\n".join(text_chunks) if text_chunks else getattr(resp, "output_text", "") or str(resp)
		logger.debug(f"Model raw output length for case {case_id}: {len(raw_output)}")
	except Exception as e:  # model call failure
		logger.error(f"Model call failed for case {case_id}: {e}")
		raw_output = f"MODEL_CALL_ERROR: {e}"

	parsed: Optional[Dict[str, Any]] = None
	parse_error: Optional[str] = None
	if raw_output and not raw_output.startswith("MODEL_CALL_ERROR"):
		match = re.search(r"{[\s\S]*}", raw_output)
		if match:
			try:
				parsed = json.loads(match.group(0))
			except Exception as exc:  # invalid JSON
				parse_error = f"JSON parse failed: {exc}"
				logger.warning(f"JSON parse error for case {case_id}: {exc}")
	else:
		parse_error = raw_output

	overall_score = 0.0
	notes = "Model produced no structured evaluation."
	risks = None
	deployment_risks = None
	filtered: Optional[Dict[str, Any]] = None
	if parsed:
		# Keep only allowed keys
		allowed_keys = {"overallScore", "risks", "correctionsRecommended", "deploymentRisks"}
		filtered = {k: v for k, v in parsed.items() if k in allowed_keys}
		overall_score = float(parsed.get("overallScore", 0) or 0)
		risks = parsed.get("risks")
		deployment_risks = parsed.get("deploymentRisks")
		notes_parts = []
		if risks:
			notes_parts.append(f"{len(risks)} risks identified")
		if deployment_risks:
			notes_parts.append(f"{len(deployment_risks)} deployment risks")
		notes = "; ".join(notes_parts) if notes_parts else notes
		logger.info(f"Case {case_id} evaluated: score={overall_score:.3f}")
	elif parse_error:
		notes = parse_error
		logger.info(f"Case {case_id} evaluation produced parse error or no structured JSON")

	overall_passed = overall_score >= 0.7
	return PlanReview(
		case_id=case_id,
		goal=goal,
		checks=[],
		score=overall_score,
		overall_passed=overall_passed,
		notes=notes + (" | raw snippet truncated" if len(raw_output) > 4000 else ""),
		risks=risks,
		evaluation_raw=filtered,
		deployment_risks=deployment_risks,
	)


async def process(root: Path, model: str, override_existing: bool = False) -> PlanReview:
	"""Process a single infrastructure-plan.json from the root directory."""
	base_prompt = PROMPT_FILE.read_text(encoding="utf-8") if PROMPT_FILE.exists() else "You are an Azure infra plan evaluator. Return JSON."
	logger.info(f"Starting processing root={root} model={model}")

	plan_path = root / INFRA_PLAN_FILENAME
	out_path = root / OUTPUT_FILENAME

	if out_path.exists() and not override_existing:
		logger.info(f"Skipping: existing {OUTPUT_FILENAME} detected (use --override-existing to reprocess)")
		with out_path.open("r", encoding="utf-8") as f:
			existing = json.load(f)
		return PlanReview(
			case_id="plan",
			goal=existing.get("goal"),
			checks=[],
			score=existing.get("score", 0),
			overall_passed=existing.get("overall_passed", False),
			notes="Loaded from existing result.",
		)

	if not plan_path.exists():
		logger.warning(f"Missing plan file: {plan_path}")
		review = PlanReview(
			case_id="plan",
			goal=None,
			checks=[
				CheckResult(
					name="file.exists",
					passed=False,
					details=f"Missing {INFRA_PLAN_FILENAME} in {root}",
				)
			],
			score=0.0,
			overall_passed=False,
			notes="Infra plan file missing.",
		)
		with out_path.open("w", encoding="utf-8") as f:
			json.dump(review.to_json(), f, indent=2)
		return review

	try:
		plan = load_plan(plan_path)
		logger.debug(f"Loaded plan from {plan_path}")
		review = await evaluate_plan_llm(plan, "plan", model=model, base_prompt=base_prompt)
		with out_path.open("w", encoding="utf-8") as f:
			json.dump(review.to_json(), f, indent=2)
		logger.info(f"Wrote review -> {out_path}")
	except Exception as exc:
		logger.exception(f"Error evaluating plan: {exc}")
		review = PlanReview(
			case_id="plan",
			goal=None,
			checks=[
				CheckResult(
					name="file.parse",
					passed=False,
					details=f"Error parsing plan: {exc}",
				)
			],
			score=0.0,
			overall_passed=False,
			notes="Parsing failed.",
		)
		with out_path.open("w", encoding="utf-8") as f:
			json.dump(review.to_json(), f, indent=2)

	return review


async def main_async():
	parser = argparse.ArgumentParser(description="Evaluate infrastructure plan from .azure/ directory.")
	parser.add_argument("--root", default=".azure", help="Directory containing infrastructure-plan.json (default: .azure)")
	parser.add_argument("--model", default="gpt-5-mini", help="Azure OpenAI deployment name")
	parser.add_argument("--log-level", default="INFO", help="Logging level (DEBUG, INFO, WARNING, ERROR)")
	parser.add_argument("--override-existing", action="store_true", help="Reprocess and overwrite existing plan_review_result.json if present")
	args = parser.parse_args()

	# Adjust log level
	try:
		logger.setLevel(getattr(logging, args.log_level.upper()))
	except Exception:
		logger.warning(f"Invalid log level '{args.log_level}', defaulting to INFO")
		logger.setLevel(logging.INFO)

	logger.info("Starting plan review run")

	root = Path(args.root)
	if not root.exists() or not root.is_dir():
		raise SystemExit(f"Root path not found or not a directory: {root}")

	review = await process(root, model=args.model, override_existing=args.override_existing)

	summary = {
		"root": str(root),
		"score": round(review.score, 3),
		"overall_passed": review.overall_passed,
		"goal": review.goal,
	}
	logger.info(f"Summary: score={summary['score']} passed={summary['overall_passed']}")
	print(json.dumps(summary, indent=2))


if __name__ == "__main__":  # pragma: no cover
	asyncio.run(main_async())
