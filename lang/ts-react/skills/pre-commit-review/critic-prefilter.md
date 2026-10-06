`git diff --cached -- '*.ts' '*.tsx' | grep -E '^\+.*(//|/\*\*)' | grep -vE '(//|/\*)\s*(eslint-(disable|enable)|@ts-(expect-error|ignore|nocheck)|prettier-ignore|/ <reference)|// =>'`
