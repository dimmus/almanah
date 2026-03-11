// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Adw;

public int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain ("almanah", "/usr/share/locale");
    Intl.bind_textdomain_codeset ("almanah", "UTF-8");
    Intl.textdomain ("almanah");

    Adw.init ();

    var app = new Almanah.Application ();
    return app.run (args);
}

