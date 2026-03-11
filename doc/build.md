## Building Almanah

- **Debug build (recommended while hacking)**:

```bash
make
```

This wipes any existing `build` dir, runs `meson setup build -Dbuildtype=debug`, then compiles.

- **Run from the build tree**:

```bash
make run
```

This rebuilds if needed and launches Almanah via `meson devenv` so the right runtime paths and schemas are used.

- **Release build**:

```bash
make release
```

This creates an optimized build suitable for packaging or performance testing.

