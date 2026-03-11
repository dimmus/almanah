Almanah
=======

Almanah is a small GTK application to allow you to keep a diary of your life.

Architecture
------------

The application is written in Vala and uses GTK 4 with libadwaita. The UI is
defined in Blueprint (`.blp`) files, compiled into GResources. The codebase
layout:

 - src/vala/app/     – Application entrypoint, MainWindow
 - src/vala/model/   – Entry, StorageManager, data models
 - src/vala/ui/      – Dialog controllers (search, preferences, import/export, etc.)
 - src/vala/widgets/ – Custom widgets (Tag, TagEntry, EntryTagsArea)
 - src/vala/tests/   – Unit tests for models and widgets
 - src/ui/           – Blueprint (.blp) files

Dependencies
---

 * [GNOME platform](https://www.gnome.org/) (GTK 4, libadwaita)
 * [SQLite 3](http://sqlite.org/)
 * [libspelling](https://gitlab.gnome.org/GNOME/libspelling) (optional, for spell checking)
 * [Evolution Data Server](https://wiki.gnome.org/Apps/Evolution) (optional, for evolution integration)

Documentation
---

Developer-oriented documentation, including build and debug instructions, lives
under the `doc/` directory:

 * `doc/usage.md` – basic usage overview
 * `doc/build.md` – how to build with Meson/Ninja
 * `doc/debug.md` – tips for debugging and profiling
 
The `doc/meson.build` file integrates these pages with [gi-docgen](https://gnome.pages.gitlab.gnome.org/gi-docgen/)
so API and developer documentation can be built as part of the Meson project.
