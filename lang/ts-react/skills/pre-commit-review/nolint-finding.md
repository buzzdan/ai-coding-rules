Also in-context: a new `eslint-disable` (any form), `@ts-expect-error` or `@ts-ignore`
in the diff, or a new rule turned off or `ignores` entry added in `eslint.config.*`,
or a new `exclude`/`skipLibCheck`-style loosening in `tsconfig*.json`, is itself a
finding — the change must justify, with evidence, that the rule genuinely does not
apply. Both directive families are suppressions: an `@ts-expect-error` on
`return undefined` silences R1 Q4 as surely as an
`// eslint-disable-next-line sonarjs/cognitive-complexity` silences R3.
