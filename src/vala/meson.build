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

vala_glib = '--target-glib=2.74'
vala_gres = [
  '--gresources=' + meson.project_source_root() / 'src' / 'almanah.gresource.xml',
  '--gresourcesdir=' + meson.project_build_root(),
  '--gresourcesdir=' + meson.project_source_root() / 'src',
]
schema_env = {'GSETTINGS_SCHEMA_DIR': meson.project_build_root() / 'data'}

foreach name : ['storage-manager', 'entry', 'import-export-operations', 'evolution-events']
  exe_name = name + '-test'
  sources = {
    'storage-manager': ['tests/storage-manager-test.vala', 'model/entry.vala', 'model/storage-manager.vala'],
    'entry': ['tests/entry-test.vala', 'model/entry.vala'],
    'import-export-operations': ['tests/import-export-operations-test.vala', 'model/entry.vala', 'model/storage-manager.vala', 'model/import-export-operations.vala'],
    'evolution-events': ['tests/evolution-events-test.vala', 'model/evolution-events.vala'],
  }[name]
  args = [vala_glib]
  exe_sources = sources
  needs_schema = false
  if name in ['storage-manager', 'import-export-operations']
    args = ['--pkg=posix'] + args
    exe_sources = sources + [almanah_resources]
    needs_schema = true
  endif
  exe = executable(exe_name, exe_sources, dependencies: vala_deps, vala_args: args)
  test(name, exe, env: needs_schema ? schema_env : {})
endforeach

widgets_test = executable('widgets-test',
  ['tests/widgets-test.vala', 'widgets/tag.vala', 'widgets/tag-entry.vala', 'widgets/entry-tags-area.vala',
   'widgets/calendar-button.vala', 'widgets/hyperlink-tag.vala', 'model/storage-manager.vala', 'model/entry.vala'],
  almanah_resources, dependencies: vala_deps,
  vala_args: [vala_glib] + vala_gres)
test('widgets', widgets_test, env: schema_env, suite: ['gui'])