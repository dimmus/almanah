kind: meson

# BuildStream element for Almanah, intended to be dropped into a
# `gnome-build-meta` style project.
#
# NOTE: You will likely want to:
#  - Adjust the `url` below to point at the canonical Almanah git repo.
#  - Adjust `track`/`ref` to whatever branch/commit you want to build.
#  - Tweak `build-depends`/`depends` to match the exact element names
#    used in your GNOME/FreeDesktop SDK stack.

sources:
- kind: git_repo
  # TODO: Point this to the canonical Almanah repository.
  # For example, if you host it on GNOME GitLab, this might be:
  #   url: gnome_gitlab:dimmus/almanah.git
  url: https://example.com/dimmus/almanah.git
  track: main
  ref: master

build-depends:
  # Meson build tooling & desktop-file utilities from freedesktop-sdk.
  # Names assume a recent freedesktop-sdk / gnome-build-meta layout.
  # Adjust if they differ in your stack.
  - freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
  - freedesktop-sdk.bst:components/desktop-file-utils.bst

depends:
  # Core GNOME platform bits Almanah needs at runtime and build time.
  # These names are examples; align them with your gnome-build-meta.
  - sdk/glib.bst
  - sdk/gtk.bst
  - sdk/libadwaita.bst
  - sdk/pango.bst
  - sdk/cairo.bst
  - sdk/gdk-pixbuf.bst
  - sdk/gtksourceview.bst
  - sdk/sqlite.bst
  - sdk/libgee.bst
  - sdk/libspelling.bst
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

