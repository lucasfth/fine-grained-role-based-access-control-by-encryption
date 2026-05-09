= Discussion

Design choices for a potential future.
Footer should not store any KEK id nor wrapped DEK (this is was a leftover design choice from the research project).
Custom encryption/decryption library should be implemented to support in-place per column cryptography.
These two changes would allow most range operations and other issues to be mitigated, as currently the range requests are incorrect as OSWS modifies the Parquet size.