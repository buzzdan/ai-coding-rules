`git diff --cached -- '*.py' | grep -E '^\+.*(#|""")' | grep -vE '#\s*(noqa|type:|pragma|fmt:|pylint:|ruff:|isort:)|>>>'`
