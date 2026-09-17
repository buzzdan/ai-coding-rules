- [ ] Every doc comment fits its tier budget — helper 0–1 / contract 2–3 /
      crossroads ≤5 prose lines (R9's tiered comment policy); overflow moved to the
      feature doc, `doc.go` (~20–30 lines) used for package docs that earn it
- [ ] Menu sections included only where they earn their place for that symbol,
      within the tier budget
- [ ] Crossroads that deserve richer inline godoc got an expand recommendation in
      the report — never extra lines beyond budget
- [ ] `See docs/<feature>.md` edge present wherever a feature doc exists — on its
      own trailing line, never woven into the summary sentence
- [ ] Testable examples: at least one `Example_*` per complex/core type; runnable;
      happy path only; `// Output:` comments included
