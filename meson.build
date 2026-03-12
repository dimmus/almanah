# SPDX-License-Identifier: GPL-3.0-or-later
project('almanah', 'vala',
          version: '0.15.99',
    meson_version: '>= 1.2.0',
  default_options: [ 'warning_level=2', 'werror=false', ],
          license: 'GPL-3.0-or-later',
)

gnome = import('gnome')
i18n = import('i18n')

data_dir = meson.project_source_root() / 'data'
po_dir = meson.project_source_root() / 'po'

prefix = get_option('prefix')
datadir = prefix / get_option('datadir')
icondir = datadir / 'icons' / 'hicolor'
schemadir = datadir / 'glib-2.0' / 'schemas'
gettext_package = meson.project_name()

libecal = dependency('libecal-2.0', version: '>= 3.33.2', required: false)
libedataserver = dependency('libedataserver-1.2', version: '>= 2.28', required: false)
have_evolution = libecal.found() and libedataserver.found()

libspelling = dependency('libspelling-1', version: '>= 0.2.0', required: true)
have_spell_check = libspelling.found()

appstreamcli = find_program('appstreamcli', required: false)
desktop_file_validate = find_program('desktop-file-validate', required: false)

vala_deps = [
	dependency('glib-2.0', version: '>= 2.80'),
	dependency('gtk4', version: '>= 4.10'), # Ubuntu 24.04 ships GTK 4.14
	dependency('libadwaita-1', version: '>= 1.4'),
	dependency('gio-2.0'),
	dependency('gtksourceview-5', version: '>= 5.4'), # Ubuntu 24.04 ships GtkSourceView 5.12
	dependency('sqlite3'),
	dependency('cairo'),
 	dependency('gee-0.8'),
 	dependency('pangocairo'),
	libspelling,
]

seahorse = find_program('seahorse', required: false)

version = meson.project_version()
if get_option('buildtype') == 'debug'
  version += '.' + run_command('git', 'rev-parse', '--short', 'HEAD', check: true).stdout().strip()
  add_project_arguments(['--define=DEBUG', '--define=DEVEL_BUILD'], language: 'vala')
endif

if have_evolution
  add_project_arguments(['--define=HAVE_EVOLUTION'], language: 'vala')
endif

add_project_arguments ('-DGETTEXT_PACKAGE="' + gettext_package + '"', '-w', language: 'c')

subdir('data')
subdir('src')
subdir('po')

gnome.post_install(
     glib_compile_schemas: true,
    gtk_update_icon_cache: true,
  update_desktop_database: false,
     update_mime_database: false,
)

summary({
    'Evolution support': have_evolution,
    'Seahorse support': seahorse.found(),
    'Spell checking': have_spell_check,
  },
  section: 'Features',
  bool_yn: true
)
