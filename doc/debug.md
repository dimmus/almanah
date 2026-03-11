## Debugging Almanah

- **Run with extra GLib checks**:

```bash
G_DEBUG=fatal-warnings G_MESSAGES_DEBUG=all make run
```

- **Address/undefined behavior sanitizers**:

```bash
make asan   # AddressSanitizer build and run
make ubsan  # UBSan build and run
```

- **Valgrind leak check**:

```bash
make valgrind-mem
```

- **Valgrind heap profiling (Massif)**:

```bash
make valgrind-massif
```

