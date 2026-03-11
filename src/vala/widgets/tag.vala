// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;

namespace Almanah {

public class Tag : Gtk.Box {
    public string tag_text { get; construct; }

    public signal void remove_clicked ();

    public Tag (string tag_text) {
        Object (tag_text: tag_text);
    }

    construct {
        orientation = Orientation.HORIZONTAL;
        spacing = 4;
        margin_start = 2;
        margin_end = 2;
        add_css_class ("tag");

        var label = new Gtk.Label (tag_text) {
            xalign = 0
        };
        append (label);

        var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_btn.add_css_class ("flat");
        close_btn.add_css_class ("circular");
        close_btn.tooltip_text = _("Remove tag");
        close_btn.clicked.connect (() => remove_clicked ());
        append (close_btn);
    }
}

}
