project('danboruthingi', 'vala', 'c',
    version: '0.2.0',
    meson_version: '>= 0.50.0',
)

add_project_arguments('--vapidir=' + meson.current_source_dir() / 'vapi', language: 'vala')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk4'),
    dependency('libsoup-3.0'),
    dependency('json-glib-1.0'),
    dependency('gdk-pixbuf-2.0'),
    dependency('libadwaita-1'),
]

sources = files(
    'src/main.vala',
    'src/application.vala',
    'src/config.vala',
    'src/models/post.vala',
    'src/api/danbooru.vala',
    'src/widgets/thumbnail.vala',
    'src/widgets/post_detail.vala',
    'src/widgets/download_dialog.vala',
    'src/window.vala',
)

executable('danboruthingi', sources,
    dependencies: dependencies,
    install: false,
)
