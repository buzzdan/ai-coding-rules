---
type: regex
pattern: 'Core Domain Types'
target: trace
---
The `Core Domain Types (leaf):` block of the DESIGN PLAN, where each candidate
type carries its R1 juiciness verdict. This is the deterministic stand-in for
the plan-quality llm grader the plan asked for: the runner applies graders in
filename order and appends postcheck LAST, so a judge cannot read a
postcheck-extracted plan file. postcheck.sh still writes the plan block to
$EVAL_OUT/design-plan.txt for human review.
