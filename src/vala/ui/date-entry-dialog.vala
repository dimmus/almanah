// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using Adw;
using GLib;

namespace Almanah {

public class DateEntryDialog : Adw.Dialog {
    private Gtk.Entry date_entry;
    private Gtk.Button ok_btn;
    private Date _date;

    public Date date {
        get { return _date; }
        set {
            _date = value;
            if (date_entry != null) {
                date_entry.text = "%d/%d/%d".printf (
                    _date.get_day (), _date.get_month (), _date.get_year ()
                );
            }
            notify_property ("date");
        }
    }

    public signal void done (Date? date);

    public DateEntryDialog () {
        title = _("Select Date");

        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_start = 24,
            margin_end = 24,
            margin_top = 24,
            margin_bottom = 24,
            spacing = 12
        };

        date_entry = new Gtk.Entry () {
            hexpand = true
        };
        date_entry.notify["text"].connect (ded_date_entry_notify_text_cb);
        date_entry.activate.connect (on_ok_clicked);
        content.append (date_entry);

        var desc_label = new Gtk.Label (
            _("e.g. \"14/03/2009\" or \"14th March 2009\".")
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

        content_width = 350;
        child = content;
    }

    void ded_date_entry_notify_text_cb (Object gobject, ParamSpec param_spec) {
        var parsed = parse_date (date_entry.text);
        ok_btn.sensitive = parsed.valid ();
        if (parsed.valid ())
            _date = parsed;
    }

    void on_ok_clicked () {
        var parsed = parse_date (date_entry.text);
        if (parsed.valid ()) {
            _date = parsed;
            done (_date);
            close ();
        }
    }

    static Date parse_date (string text) {
        var d = Date ();
        d.set_parse (text);
        return d;
    }
}

}
