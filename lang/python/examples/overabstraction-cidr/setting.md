During the refactor of a K3s configuration function (`align_cidr_args`, originally 60
lines mixing string parsing, boolean flag tracking, and triplicated `match` arms), two
booleans tracked related state:

```python
is_cluster_cidr_set = False
is_server_cidr_set = False
# ... a parsing loop sets them ...
if is_cluster_cidr_set and is_server_cidr_set:
    return  # both set, nothing to do
```
