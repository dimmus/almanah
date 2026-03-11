// SPDX-License-Identifier: GPL-3.0-or-later

Almanah
=======

Almanah is a small GTK+ application to allow you to keep a diary of your life.

Architecture
------------

The application is written in Vala and uses GTK 4 with libadwaita. The main
window UI is defined in Blueprint (main-window.blp); other dialogs use
GtkBuilder XML. The codebase layout:

 - src/vala/app/     – Application entrypoint, MainWindow
 - src/vala/model/   – Entry, StorageManager, data models
 - src/vala/ui/      – Dialog controllers (search, preferences, import/export, etc.)
 - src/vala/widgets/ – Custom widgets (Tag, TagEntry, EntryTagsArea)
 - src/ui/           – Blueprint (.blp) and GtkBuilder (.ui) files

News
---

See NEWS file.

Dependencies
---

 * [GNOME 3.0 development platform](http://www.gnome.org/)
 * [SQLite 3](http://sqlite.org/)
 * [libspelling](https://gitlab.gnome.org/GNOME/libspelling) (optional, for spell checking)
 * [GPGME](http://www.gnupg.org/gpgme.html) (optional)
 * [Evolution Data Server](https://wiki.gnome.org/Apps/Evolution) (optional)

Copyright
---

Philip Withnall <philip@tecnocode.co.uk>

Icon by Jakub Szypulka <cube@szypulka.com>

Bugs
---

Bugs should be [filed in GNOME GitLab](https://gitlab.gnome.org/GNOME/almanah/issues/new).

To get better debug output, run:
```
almanah --debug
```

Contact
---

 * https://wiki.gnome.org/Apps/Almanah_Diary
