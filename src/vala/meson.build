config_data = configuration_data()
config_data.set('project_version', version)

config_vala = configure_file(
  input: 'config.vala.in',
  output: 'config.vala',
  configuration: config_data,
)

vala_sources = files(
  'app/main.vala',
  'app/application.vala',
  'app/main-window.vala',
  'model/entry.vala',
  'model/evolution-events.vala',
  'model/storage-manager.vala',
  'model/import-export-operations.vala',
  'ui/search-dialog.vala',
  'ui/preferences-dialog.vala',
  'ui/uri-entry-dialog.vala',
  'ui/date-entry-dialog.vala',
  'ui/import-export-dialog.vala',
  'widgets/tag.vala',
  'widgets/tag-entry.vala',
  'widgets/entry-tags-area.vala',
  'widgets/calendar-button.vala',
  'widgets/hyperlink-tag.vala',
) + [config_vala]

almanah_vala = executable(meson.project_name(),
  vala_sources,
  almanah_resources,
  dependencies: vala_deps,
  vala_args: [
    '--target-glib=2.74',
    '--gresources=' + meson.project_source_root() / 'src' / 'almanah.gresource.xml',
    '--gresourcesdir=' + meson.project_build_root(),
    '--gresourcesdir=' + meson.project_source_root() / 'src',
  ],
  install: true,
)

storage_manager_test = executable('storage-manager-test',
  [
    'tests/storage-manager-test.vala',
    'model/entry.vala',
    'model/storage-manager.vala',
  ],
  almanah_resources,
  dependencies: vala_deps,
  vala_args: [
    '--pkg=posix',
    '--target-glib=2.74',
  ],
)

test('storage-manager', storage_manager_test,
  env: {
    'GSETTINGS_SCHEMA_DIR': meson.project_build_root() / 'data',
  },
)

entry_test = executable('entry-test',
  [
    'tests/entry-test.vala',
    'model/entry.vala',
  ],
  dependencies: vala_deps,
  vala_args: [
    '--target-glib=2.74',
  ],
)

test('entry', entry_test)

import_export_test = executable('import-export-operations-test',
  [
    'tests/import-export-operations-test.vala',
    'model/entry.vala',
    'model/storage-manager.vala',
    'model/import-export-operations.vala',
  ],
  almanah_resources,
  dependencies: vala_deps,
  vala_args: [
    '--pkg=posix',
    '--target-glib=2.74',
  ],
)

test('import-export-operations', import_export_test,
  env: {
    'GSETTINGS_SCHEMA_DIR': meson.project_build_root() / 'data',
  },
)

evolution_events_test = executable('evolution-events-test',
  [
    'tests/evolution-events-test.vala',
    'model/evolution-events.vala',
  ],
  dependencies: vala_deps,
  vala_args: [
    '--target-glib=2.74',
  ],
)

test('evolution-events', evolution_events_test)

widgets_test = executable('widgets-test',
  [
    'tests/widgets-test.vala',
    'widgets/tag.vala',
    'widgets/tag-entry.vala',
    'widgets/entry-tags-area.vala',
    'widgets/calendar-button.vala',
    'widgets/hyperlink-tag.vala',
    'model/storage-manager.vala',
    'model/entry.vala',
  ],
  almanah_resources,
  dependencies: vala_deps,
  vala_args: [
    '--target-glib=2.74',
    '--gresources=' + meson.project_source_root() / 'src' / 'almanah.gresource.xml',
    '--gresourcesdir=' + meson.project_build_root(),
    '--gresourcesdir=' + meson.project_source_root() / 'src',
  ],
)

test('widgets', widgets_test,
  env: {
    'GSETTINGS_SCHEMA_DIR': meson.project_build_root() / 'data',
  },
)