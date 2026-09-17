```text
❌ userResponse is the flat REST response shape for a user account
   (spec §4). It deliberately has NO field for the password hash — the
   response omission is structural (T-04-02), not an accident of the
   default value ... additive to the {uid} addressing scheme (D-06/D-07).

✅ userResponse is the flat REST response shape for a user account.
   It has no field for the password hash or the API token, so a response
   can never leak them.
   See docs/accounts-api.md.
```