// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using GLib;

namespace Almanah {

public class EntryTagsArea : Gtk.Box {
    public Entry? entry { get; set; }
    public StorageManager? storage_manager { get; set; }
    public Gtk.Widget? back_widget { get; set; }

    private Gtk.FlowBox flow_box;
    private TagEntry tag_entry;
    private int tags_number;

    public EntryTagsArea () {
        Object (
            orientation: Orientation.HORIZONTAL,
            spacing: 6
        );
    }

    construct {
        flow_box = new Gtk.FlowBox () {
            orientation = Orientation.HORIZONTAL,
            selection_mode = SelectionMode.NONE
        };

        tag_entry = new TagEntry () {
            width_chars = 10
        };
        tag_entry.activate.connect (() => tag_entry_activate_cb (tag_entry.text));

        flow_box.insert (tag_entry, -1);
        append (flow_box);

        notify["entry"].connect (update);
        notify["storage-manager"].connect (on_storage_manager_changed);
    }

    void on_storage_manager_changed () {
        tag_entry.storage_manager = storage_manager;
    }

    void update () {
        clear_tags ();
        if (entry != null && storage_manager != null) {
            load_tags ();
        }
    }

    void clear_tags () {
        var child = flow_box.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();

            // FlowBox children are Gtk.FlowBoxChild; Tag is inside as its child.
            // Use flow_box.remove(inner) so the container updates its internals correctly.
            if (child is Gtk.FlowBoxChild) {
                var inner = ((Gtk.FlowBoxChild) child).get_child ();
                if (inner is Tag) {
                    flow_box.remove ((Widget) inner);
                    if (tags_number > 0)
                        tags_number--;
                }
            }

            child = next;
        }
    }

    void load_tags () {
        if (entry == null || storage_manager == null)
            return;

        var tags = storage_manager.get_entry_tags (entry.date);
        foreach (var tag in tags) {
            add_tag (tag);
        }
    }

    void add_tag (string tag) {
        var tag_widget = new Tag (tag);
        tag_widget.remove_clicked.connect (() => on_tag_remove (tag));
        flow_box.insert (tag_widget, -1);
        tags_number++;
    }

    void on_tag_remove (string tag) {
        if (entry == null || storage_manager == null)
            return;

        try {
            storage_manager.remove_entry_tag (entry.date, tag);
            update ();
            if (back_widget != null)
                back_widget.grab_focus ();
        } catch (Error e) {
            warning ("Failed to remove tag: %s", e.message);
        }
    }

    void tag_entry_activate_cb (string? tag_name) {
        var tag = (tag_name ?? "").strip ();
        if (tag == "" || entry == null || storage_manager == null)
            return;

        var existing = storage_manager.get_entry_tags (entry.date);
        foreach (var t in existing) {
            if (t == tag)
                return;
        }

        try {
            storage_manager.add_entry_tag (entry.date, tag);
            tag_entry.text = "";
            update ();
            if (back_widget != null)
                back_widget.grab_focus ();
        } catch (Error e) {
            warning ("Failed to add tag: %s", e.message);
        }
    }
}

}
