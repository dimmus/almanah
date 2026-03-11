## Building Almanah

- **Debug build (recommended while hacking)**:

```bash
meson setup build --wipe -Dbuildtype=debug
ninja -C build
```

This wipes any existing `build` dir, runs Meson in debug mode, then compiles with Ninja.

- **Run from the build tree**:

```bash
meson devenv -C build -- almanah
```

This launches Almanah via `meson devenv` so the right runtime paths and schemas are used. Rebuild first with `ninja -C build` if you have changed sources.

- **Release build**:

```bash
meson setup build-release --wipe -Dbuildtype=release
ninja -C build-release
```

This creates an optimized build suitable for packaging or performance testing.

