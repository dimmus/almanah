[![Only on Flathub](https://img.shields.io/badge/Only_on_Flathub-white?logo=flathub&logoColor=white&labelColor=black)][Only on Flathub]
[![Installs](https://img.shields.io/flathub/downloads/com.dimmus.almanah?label=Installs)][Flathub]
[![Please do not theme this app](https://stopthemingmy.app/badge.svg)](https://stopthemingmy.app)

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

Made for GNOME & Flatpak
---

Almanah is designed and developed on and for GNOME. As such, contributors agree to abide by the [GNOME Code of Conduct](https://wiki.gnome.org/Foundation/CodeOfConduct).

<a href='https://flathub.org/apps/details/com.dimmus.almanah'><img width='196' alt='Download on Flathub' src='https://flathub.org/api/badge?locale=en'/></a>

Almanah is distributed and supported [only on Flathub]. Versions using other packagaging formats or on other app stores are **not** supported by me and may not work the same.

Developing and Building
---

I recommend using GNOME Builder for development.
