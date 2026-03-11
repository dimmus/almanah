// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using Adw;
using GLib;

namespace Almanah {

public class SearchResultRow : Object {
    public int day { get; construct; }
    public int month { get; construct; }
    public int year { get; construct; }
    public string formatted_date { get; construct; }
    public string? icon_name { get; construct; }

    public SearchResultRow (int day, int month, int year, string formatted_date, string? icon_name) {
        Object (
            day: day,
            month: month,
            year: year,
            formatted_date: formatted_date,
            icon_name: icon_name
        );
    }
}

[GtkTemplate (ui = "/org/gnome/Almanah/ui/search-dialog.ui")]
public class SearchDialog : Adw.Dialog {
    [GtkChild] unowned Gtk.Entry sd_search_entry;
    [GtkChild] unowned Gtk.Button sd_search_button;
    [GtkChild] unowned Gtk.Button sd_cancel_button;
    [GtkChild] unowned Gtk.Spinner sd_search_spinner;
    [GtkChild] unowned Gtk.Label sd_results_label;
    [GtkChild] unowned Gtk.Widget sd_results_alignment;
    [GtkChild] unowned Gtk.ListView sd_results_list_view;
    [GtkChild] unowned Gtk.Button sd_view_button;

    private GLib.ListStore results_store;
    private StorageManager storage_manager;
    private MainWindow main_window;

    public SearchDialog (StorageManager storage_manager, MainWindow main_window) {
        this.storage_manager = storage_manager;
        this.main_window = main_window;

        results_store = new GLib.ListStore (typeof (SearchResultRow));
        var single_sel = new Gtk.SingleSelection (results_store);
        sd_results_list_view.model = single_sel;

        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect (sd_results_list_item_setup_cb);
        factory.bind.connect (sd_results_list_item_bind_cb);
        sd_results_list_view.factory = factory;

        sd_results_list_view.activate.connect (sd_results_list_view_activate_cb);
        single_sel.notify["selected"].connect (() => {
            sd_view_button.sensitive = single_sel.selected != Gtk.INVALID_LIST_POSITION;
        });

        sd_view_button.sensitive = false;
        sd_cancel_button.sensitive = true;
    }

    void sd_results_list_item_setup_cb (Object factory, Object object) {
        var item = (Gtk.ListItem) object;
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var img = new Gtk.Image ();
        var label = new Gtk.Label (null) {
            xalign = 0
        };
        box.append (img);
        box.append (label);
        item.child = box;
    }

    void sd_results_list_item_bind_cb (Object factory, Object object) {
        var item = (Gtk.ListItem) object;
        var row = (SearchResultRow?) item.item;
        if (row == null)
            return;

        var box = (Gtk.Box) item.child;
        var img = (Gtk.Image) box.get_first_child ();
        var label = (Gtk.Label) img.get_next_sibling ();

        img.set_from_icon_name (row.icon_name ?? "");
        label.label = row.formatted_date;
    }

    [GtkCallback]
    void sd_results_list_view_activate_cb (Gtk.ListView view, uint position) {
        var model = (Gtk.SingleSelection) view.model;
        var row = (SearchResultRow?) model.model.get_item (position);
        if (row != null)
            select_date_from_row (row);
    }

    void select_date_from_row (SearchResultRow row) {
        var date = Date ();
        date.set_dmy ((DateDay) row.day, (DateMonth) row.month, (DateYear) row.year);
        main_window.select_date (date);
    }

    [GtkCallback]
    void sd_search_button_clicked_cb () {
        results_store.remove_all ();

        var search_string = sd_search_entry.text.strip ();
        if (search_string == "") {
            sd_results_alignment.visible = false;
            sd_results_label.label = _("Nothing found");
            return;
        }

        sd_results_alignment.visible = true;
        sd_results_label.label = _("Searching…");
        sd_search_spinner.visible = true;
        sd_search_spinner.spinning = true;
        sd_search_button.sensitive = false;

        var results = storage_manager.search_entries (search_string);
        int count = 0;

        foreach (var entry in results) {
            var date = entry.date;
            var formatted = format_date (date);
            var icon = entry.important ? "emblem-important" : null;
            results_store.append (new SearchResultRow (
                date.get_day (),
                date.get_month (),
                date.get_year (),
                formatted,
                icon
            ));
            count++;
        }

        sd_search_spinner.spinning = false;
        sd_search_spinner.visible = false;
        sd_search_button.sensitive = true;

        if (count == 0) {
            sd_results_label.label = _("Nothing found");
        } else if (count == 1) {
            sd_results_label.label = _("Found %d entry:").printf (count);
        } else {
            sd_results_label.label = _("Found %d entries:").printf (count);
        }
    }

    string format_date (Date date) {
        return "%d/%d/%d".printf (date.get_day (), date.get_month (), date.get_year ());
    }

    [GtkCallback]
    void sd_cancel_button_clicked_cb () {
        // Close the dialog; search is synchronous so there is nothing to abort.
        close ();
    }

    [GtkCallback]
    void sd_view_button_clicked_cb () {
        var model = (Gtk.SingleSelection) sd_results_list_view.model;
        var item = model.selected_item;
        if (item != null) {
            var row = (SearchResultRow) item;
            select_date_from_row (row);
        }
    }
}

}
