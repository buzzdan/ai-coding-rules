---
name: documentation
description: |
  Creates concise, behavior-focused documentation for humans and AI.
  Use after feature implementation OR bug fixes to document HOW THE PRODUCT BEHAVES.
  NOT a changelog - documents current behavior, not change history.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - mcp__ide__getDiagnostics
---

<objective>
Creates concise, behavior-focused documentation that answers: **"How does this product/feature work?"**

This is NOT a changelog - it's an introduction to current product behavior.

**Reference**: See `reference.md` for templates, checklists, and examples.
</objective>

<philosophy>
**The 5-Year Reader Test**: Someone reading this in 5 years doesn't care that "we fixed a bug where X happened" - they just want to know how X works NOW.

**Behavior Over History**: Document what the product DOES, not what changed. When readers come back later, they need to understand current behavior, not archaeology.

**Conciseness Over Completeness**: A focused doc that gets read beats an exhaustive doc that gets skipped. Document what matters for understanding and usage.

**Layered Documentation**: Different scopes need different docs. System-level overviews, project guides, feature docs, and code comments each serve distinct purposes. See reference.md for layer definitions.

**Documentation IS**: Explaining WHY decisions were made, providing context for future changes, showing how pieces fit together, helping both humans and AI understand intent.

**Documentation is NOT**: A changelog of commits, implementation details without context, API reference without explanation.
</philosophy>

<when_to_use>
**Features**: After implementing significant new functionality (may span multiple commits)
**Bug Fixes**: Update existing docs to reflect corrected behavior (don't add "bug fix" sections)
**Refactors**: Only if external behavior or usage patterns changed

**NOT for**: Individual commits, internal refactors that don't change behavior, changelog entries
</when_to_use>

<quick_start>
1. **Understand feature scope** - Review all commits related to the feature
2. **Analyze architecture** - Identify core types, data flow, design decisions
3. **Generate docs/[feature-name].md** - Use template from reference.md
4. **Update package godoc** - Use template from reference.md
5. **Add type documentation** - Use template from reference.md
6. **Create testable examples** - Example_* functions for complex types
7. **Validate** - Run through checklists in reference.md
</quick_start>

<workflow>

<step_1_understand_scope>
- Review all commits related to the feature
- Identify all modified/new files
- Understand the problem being solved
- Map out integration points with existing system
</step_1_understand_scope>

<step_2_analyze_architecture>
- Identify core domain types
- Map data/control flow
- Document design decisions (WHY choices were made)
- Note patterns used (vertical slice, self-validating types, etc.)
</step_2_analyze_architecture>

<step_3_choose_documentation_layer>
Before writing, decide where each piece of documentation belongs.

**Decision Questions:**
| Question | If Yes → |
|----------|----------|
| Does this affect how multiple features interact? | System docs |
| Does this explain project setup, structure, or getting started? | Project docs |
| Does this explain how ONE feature works? | Feature docs |
| Does this explain ONE type/function's purpose? | Code docs |

**The Overlap Rule:**
- **Summarize up, detail down**: Higher layers summarize, lower layers elaborate
- **Good overlap**: System doc mentions "auth uses JWT" → Feature doc explains JWT implementation
- **Bad overlap**: Same paragraph copy-pasted across multiple docs (will drift)

**Cross-Reference, Don't Duplicate:**
- System doc: "See `docs/auth.md` for authentication details"
- Feature doc: "See `UserID` godoc for validation rules"
- Code doc: "See `docs/auth.md` for architectural context"

See reference.md "Choosing Documentation Layer" for detailed decision tree.
</step_3_choose_documentation_layer>

<step_4_generate_feature_doc>
Create `docs/[feature-name].md` using the template in reference.md.

Cover:
- Problem & solution: What problem does this solve?
- **Key players**: Who are the main actors? (types, interfaces, services)
- **Entry points**: Where does execution start? (handlers, commands, events)
- Architecture: How does it work?
- Usage examples: How do I use it?
- Integration: How does it fit into the system?

**For bug fixes**: Don't create new docs. Update existing docs to reflect correct behavior.
See reference.md "Bug Fix Documentation" guidelines.
</step_4_generate_feature_doc>

<step_5_update_code_documentation>
Using templates from reference.md:

1. **Package godoc** - Update to reflect feature's role
2. **Type godoc** - Explain purpose, design decisions, constraints
3. **Function godoc** - Only for non-obvious behavior
4. **Testable examples** - Example_* functions for complex types

Code docs should reference feature docs: `See docs/[feature].md for detailed architecture`
</step_5_update_code_documentation>

<step_6_validate>
Run through the checklists in reference.md:
- Feature documentation checklist
- Code comments checklist
- Quality gates (clarity, AI, maintenance, example tests)

Key questions:
- Can someone unfamiliar understand the feature?
- Can AI use this for bug fixes without reading all code?
- Are design decisions clearly explained?
- Are integration points documented?
</step_6_validate>

<step_7_manage_size>
If documentation grows too large (>500 lines), split into folder structure.
See reference.md "Managing Documentation Size" for guidelines.
</step_7_manage_size>

</workflow>

<output_format>
After generating documentation:

```
DOCUMENTATION COMPLETE

Feature: [Feature Name]

Generated Artifacts:
- docs/[feature-name].md (created/updated)
- Package godoc updated in [package]/[file].go
- Type documentation for: [list types]
- Testable examples: [list Example_* functions]

Validation:
- [ ] Feature doc checklist passed
- [ ] Code comments checklist passed
- [ ] Quality gates passed

Next Steps:
1. Review docs/[feature-name].md for accuracy
2. Run `go test` to verify testable examples
3. Commit documentation
```
</output_format>

<success_criteria>
Documentation is complete when ALL of the following are true:

**Content:**
- [ ] Feature doc created/updated at docs/[feature-name].md
- [ ] Package godoc updated to reflect feature's role
- [ ] Key types have godoc explaining purpose and design decisions
- [ ] Testable examples created for complex/core types

**Quality:**
- [ ] Describes current behavior (not history or changelogs)
- [ ] Someone unfamiliar can understand the feature
- [ ] AI can use this for bug fixes without reading all code
- [ ] Design decisions are clearly explained with rationale

**Maintainability:**
- [ ] Doc stays focused and scannable (split if >500 lines)
- [ ] No redundant information across layers
- [ ] Cross-references between doc layers are clear
</success_criteria>
