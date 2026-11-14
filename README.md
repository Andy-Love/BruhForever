# Download stats

`downloads.csv` gets one row each time a release is published (see `scripts/stats.py` on `main`).
Columns: UTC time, release tag, then total downloads on GitHub, CurseForge, WoWInterface and Wago at that moment.
Counts only grow as people download later, so compare rows over time, not within one release.
