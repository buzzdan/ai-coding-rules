```text
# ❌ the caller's list is now the type's list; a later append bypasses the constructor
newPorts(items):    return Ports(items)
Ports.items():      return self.items

# ✅ copy on the way in; hand out a copy or an iterator on the way out
newPorts(items):    return Ports(copy of items)
Ports.each():       yield each port in self.items
```

> **Spelling:** where lists and maps are references into shared storage, a
> constructor copies what it is given and a query never returns the field itself.
> Where the language has immutable collections, storing a frozen copy is the same
> move with the copy made once; freezing the binding is not freezing the value, so a
> frozen record holding a mutable list is mutable through that list. A mutable
> default argument, where the language has them, is this rule's most common form.
