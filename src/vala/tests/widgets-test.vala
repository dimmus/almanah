// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Gtk;
using Almanah;

void add_widgets_tests () {
    Test.add_func ("/widgets/tag/remove-clicked-signal", () => {
        bool removed = false;
        var tag = new Tag ("work");
        tag.remove_clicked.connect (() => {
            removed = true;
        });

        // Emitting the signal directly should invoke handlers.
        tag.remove_clicked ();
        assert (removed);
    });

    Test.add_func ("/widgets/tag-entry/defaults", () => {
        var entry = new TagEntry ();
        assert (entry.placeholder_text == _("add tag"));
        assert (entry.tooltip_text.index_of ("press enter") >= 0);
        assert (entry.storage_manager == null);
    });

    Test.add_func ("/widgets/entry-tags-area/construct", () => {
        // Construction should succeed and initial state should be empty.
        var area = new EntryTagsArea ();
        assert (area.entry == null);
        assert (area.storage_manager == null);
    });

    // Note: CalendarButton relies on template wiring and widget parenting that
    // is fragile to exercise in headless unit tests; its behaviour is better
    // covered by higher-level UI tests.


    Test.add_func ("/widgets/hyperlink-tag/basic-properties", () => {
        var tag = new HyperlinkTag ("https://example.com");

        // The construct-only property should be stored as-is.
        assert (tag.uri == "https://example.com");

        // The construct block should have applied hyperlink styling (we can
        // only assert underline here because foreground is write-only).
        assert (tag.underline == Pango.Underline.SINGLE);
    });

    Test.add_func ("/widgets/hyperlink-tag/multiple-instances", () => {
        var first = new HyperlinkTag ("first://uri");
        var second = new HyperlinkTag ("second://uri");

        assert (first.uri == "first://uri");
        assert (second.uri == "second://uri");

        // Instances should not share mutable state accidentally.
        assert (first.uri != second.uri);
    });

    Test.add_func ("/widgets/entry-tags-area/storage-manager-propagation", () => {
        var area = new EntryTagsArea ();

        var settings = new GLib.Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (":memory:", settings);
        Error? err = null;
        assert (sm.open (out err));

        Date d = Date ();
        d.set_dmy (1, 1, 2024);
        var entry = new Almanah.Entry (d);

        area.entry = entry;
        area.storage_manager = sm;

        // Find the inner TagEntry and ensure it received the same storage manager.
        TagEntry? inner = null;
        Gtk.Widget? child = area.get_first_child ();
        while (child != null && inner == null) {
            if (child is Gtk.FlowBox) {
                var fb = (Gtk.FlowBox) child;
                var fb_child = fb.get_first_child ();
                while (fb_child != null) {
                    if (fb_child is Gtk.FlowBoxChild) {
                        var w = ((Gtk.FlowBoxChild) fb_child).get_child ();
                        if (w is TagEntry) {
                            inner = (TagEntry) w;
                            break;
                        }
                    }
                    fb_child = fb_child.get_next_sibling ();
                }
            }
            child = child.get_next_sibling ();
        }

        assert (inner != null);
        assert (inner.storage_manager == sm);
    });

    Test.add_func ("/widgets/entry-tags-area/tag-activation-adds-tag", () => {
        var settings = new GLib.Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (":memory:", settings);
        Error? err = null;
        assert (sm.open (out err));

        Date d = Date ();
        d.set_dmy (2, 1, 2024);
        var entry = new Almanah.Entry (d);

        var area = new EntryTagsArea ();
        area.entry = entry;
        area.storage_manager = sm;

        // Find TagEntry inside the area.
        TagEntry? inner = null;
        Gtk.Widget? child = area.get_first_child ();
        while (child != null && inner == null) {
            if (child is Gtk.FlowBox) {
                var fb = (Gtk.FlowBox) child;
                var fb_child = fb.get_first_child ();
                while (fb_child != null) {
                    if (fb_child is Gtk.FlowBoxChild) {
                        var w = ((Gtk.FlowBoxChild) fb_child).get_child ();
                        if (w is TagEntry) {
                            inner = (TagEntry) w;
                            break;
                        }
                    }
                    fb_child = fb_child.get_next_sibling ();
                }
            }
            child = child.get_next_sibling ();
        }

        assert (inner != null);

        // Simulate typing a tag and pressing Enter.
        inner.text = "work";
        inner.activate ();

        var tags = sm.get_entry_tags (entry.date);
        assert (tags.length == 1);
        assert (tags[0] == "work");

        // Re-activate with the same tag; StorageManager should keep it unique.
        inner.text = "work";
        inner.activate ();
        var tags_after = sm.get_entry_tags (entry.date);
        assert (tags_after.length == 1);
        assert (tags_after[0] == "work");
    });
}

public static int main (string[] args) {
    // Use in-memory GSettings backend to avoid dconf writes in test environments.
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);

    Gtk.init ();
    Test.init (ref args);

    add_widgets_tests ();

    return Test.run ();
}

