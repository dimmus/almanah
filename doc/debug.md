## Debugging Almanah

- **Run with extra GLib checks**:

```bash
G_DEBUG=fatal-warnings G_MESSAGES_DEBUG=all meson devenv -C build -- almanah
```

- **Address/undefined behavior sanitizers**:

```bash
meson setup build-asan --wipe -Dbuildtype=debug -Db_sanitize=address,undefined -Db_lundef=false
ninja -C build-asan
meson devenv -C build-asan -- almanah   # run ASan/UBSan build
```

- **Valgrind leak check**:

```bash
meson devenv -C build -- valgrind --leak-check=full --show-leak-kinds=all almanah
```

- **Valgrind heap profiling (Massif)**:

```bash
meson devenv -C build -- valgrind --tool=massif almanah
```

