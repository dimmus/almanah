gnome = import('gnome')

gi_docgen = find_program('gi-docgen', required: false)

if gi_docgen.found()
  run_target('docs',
    command: [
      gi_docgen, 'generate',
      '--quiet',
      '--config', meson.current_source_dir() / 'almanah-doc.toml',
      '--content-dir', meson.current_source_dir(),
      '--output', meson.current_build_dir(),
      'GLib-2.0',
    ]
  )
else
  message('gi-docgen not found: documentation will not be built')
endif

