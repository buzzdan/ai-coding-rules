```text
❌ by layer                          ✅ by feature, roles inside
src/app/models/rotator.py            src/app/rotator/__init__.py   # the slice's public names, in __all__
src/app/services/rotator_service.py  src/app/rotator/rotator.py
src/app/repositories/rotator_repo.py src/app/rotator/parser.py
src/app/handlers/rotator_handler.py  src/app/rotator/handler.py
                                     src/app/rotator/repository.py
```

> **In Python:** the package name is the feature noun, `rotator`, never `services`
> or `models`, and `utils.py`, `common.py` and `helpers.py` are role names too: a
> module is named for the vocabulary it holds, or the next function lands beside the
> first because it did. Role names live in module names inside the slice. Each type with
> logic sits in its own module named after the type, and `__init__.py` is the
> slice's front door: it re-exports what other slices may import and nothing else,
> and it never imports another slice, or the front doors form an import cycle.
