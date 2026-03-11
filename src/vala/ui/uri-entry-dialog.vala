// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using Adw;
using GLib;

namespace Almanah {

public class UriEntryDialog : Adw.Dialog {
    private Gtk.Entry uri_entry;
    private Gtk.Button ok_btn;
    private string _uri = "";

    public string uri {
        get { return _uri; }
        set {
            if (_uri == value)
                return;
            _uri = value ?? "";
            if (uri_entry != null)
                uri_entry.text = _uri;
            notify_property ("uri");
        }
    }

    public signal void done (string? uri);

    public UriEntryDialog () {
        title = _("Enter URI");

        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_start = 24,
            margin_end = 24,
            margin_top = 24,
            margin_bottom = 24,
            spacing = 12
        };

        uri_entry = new Gtk.Entry () {
            hexpand = true
        };
        uri_entry.notify["text"].connect (ued_uri_entry_notify_text_cb);
        uri_entry.activate.connect (on_ok_clicked);
        content.append (uri_entry);

        var desc_label = new Gtk.Label (
            _("e.g. \"http://google.com/\" or \"file:///home/me/Photos/photo.jpg\".")
        ) {
            xalign = 0,
            wrap = true
        };
        desc_label.add_css_class ("dim-label");
        content.append (desc_label);

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.END,
            margin_top = 12
        };

        var cancel_btn = new Gtk.Button.with_mnemonic (_("_Cancel"));
        cancel_btn.clicked.connect (() => {
            done (null);
            close ();
        });

        ok_btn = new Gtk.Button.with_mnemonic (_("_OK")) {
            sensitive = false
        };
        ok_btn.clicked.connect (on_ok_clicked);
        ok_btn.add_css_class ("suggested-action");

        button_box.append (cancel_btn);
        button_box.append (ok_btn);
        content.append (button_box);

        content_width = 400;
        child = content;
    }

    void ued_uri_entry_notify_text_cb (Object gobject, ParamSpec param_spec) {
        var text = uri_entry.text.strip ();
        ok_btn.sensitive = is_uri_valid (text);
        if (ok_btn.sensitive)
            _uri = text;
    }

    void on_ok_clicked () {
        if (is_uri_valid (uri_entry.text.strip ())) {
            _uri = uri_entry.text.strip ();
            done (_uri);
            close ();
        }
    }

    static bool is_uri_valid (string uri) {
        return Uri.parse_scheme (uri) != null;
    }
}

}
