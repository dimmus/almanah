service_conf = configuration_data()
service_conf.set('bindir', get_option('prefix') / get_option('bindir'))

service = 'io.github.dimmus.almanah.service'
configure_file(
  input: service + '.in',
  output: service,
  install: true,
  install_dir: datadir / 'dbus-1' / 'services',
  configuration: service_conf,
)

desktop = 'io.github.dimmus.almanah.desktop'
i18n.merge_file(
  type: 'desktop',
  input: desktop + '.in',
  output: desktop,
  po_dir: po_dir,
  install: true,
  install_dir: datadir / 'applications',
)
if desktop_file_validate.found()
  test(
    'Validating @0@'.format(desktop),
    desktop_file_validate,
    args: [desktop],
    workdir: meson.current_build_dir(),
  )
endif

appdata = 'io.github.dimmus.almanah.metainfo.xml'
i18n.merge_file(
  input: appdata + '.in',
  output: appdata,
  po_dir: po_dir,
  install: true,
  install_dir: datadir / 'metainfo',
)
if (appstreamcli.found())
  test(
    'Validating ' + appdata,
    appstreamcli,
    args: ['validate', '--no-net', '--explain', appdata],
    workdir: meson.current_build_dir(),
  )
endif

gschema_xml = 'io.github.dimmus.almanah.gschema.xml'
install_data(
  gschema_xml,
  install_dir: schemadir,
)

gnome.compile_schemas(
  depend_files: [
    gschema_xml,
  ],
)

subdir('icons')
