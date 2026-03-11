# SPDX-License-Identifier: GPL-3.0-or-later

blueprint_compiler = find_program('blueprint-compiler', required: true)

blueprint_ui_names = [
  'main-window',
  'calendar-button',
  'search-dialog',
  'preferences-dialog',
]

generated_uis = []
foreach name : blueprint_ui_names
  gt = custom_target(name + '.ui',
    input: 'ui/' + name + '.blp',
    output: name + '.ui',
    command: [
      'sh', '-c',
      'd=$(dirname "@OUTPUT@") && mkdir -p "$d/ui" && ' +
      blueprint_compiler.full_path() + ' compile --output "$d/ui/' + name + '.ui" "@INPUT@" && touch "@OUTPUT@"',
    ],
  )
  generated_uis += gt
endforeach

almanah_resources = gnome.compile_resources('almanah-resources',
  'almanah.gresource.xml',
  source_dir: [
    meson.project_build_root(),
    meson.current_build_dir(),
    meson.current_source_dir(),
    meson.project_source_root() / 'data',
  ],
  c_name: 'almanah',
  export: true,
  dependencies: generated_uis,
)

subdir('vala')
