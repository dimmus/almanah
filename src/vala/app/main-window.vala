// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using Adw;
using GtkSource;
using GLib;
using Pango;
using Spelling;

[CCode (cname = "pango_cairo_show_layout", cheader_filename = "pango/pangocairo.h")]
extern void pango_cairo_show_layout (Cairo.Context cr, Pango.Layout layout);

namespace Almanah {

[GtkTemplate (ui = "/org/gnome/Almanah/ui/main-window.ui")]
public class MainWindow : Adw.ApplicationWindow {
    [GtkChild] unowned EntryTagsArea entry_tags_area;
    [GtkChild] unowned CalendarButton calendar_button;
    [GtkChild] unowned GtkSource.View entry_view;
    [GtkChild] unowned Gtk.Expander events_expander;
    [GtkChild] unowned Gtk.ListView events_list_view;
    [GtkChild] unowned Gtk.Label events_count_label;

    private StorageManager? storage_manager;
    private Entry? current_entry;
    private Date current_date;
    private bool updating_formatting = false;
    private ulong style_manager_handler_id = 0;
    private Spelling.Checker? spell_checker;
    private Spelling.TextBufferAdapter? spell_adapter;
    private bool spell_setup = false;

    private EvolutionEventsProvider? events_provider;
    private Gtk.StringList? events_strings;
    private Gtk.SingleSelection? events_selection;

    static construct {
        typeof (EntryTagsArea);
        typeof (HyperlinkTag);
        typeof (CalendarButton);
    }

    public MainWindow (Almanah.Application app) {
        Object (application: app);
    }

    construct {
#if DEVEL_BUILD
        add_css_class ("devel");
#endif
    }

    public void init_with_storage (StorageManager? storage_manager) {
        this.storage_manager = storage_manager;
        if (entry_tags_area != null && storage_manager != null) {
            entry_tags_area.storage_manager = storage_manager;
            entry_tags_area.back_widget = entry_view;
        }
        if (calendar_button != null) {
            calendar_button.storage_manager = storage_manager;
            calendar_button.day_selected.connect (on_calendar_day_selected);
            calendar_button.select_date_clicked.connect (show_date_picker);
        }

        add_window_actions ();
        setup_events_list ();
        setup_hyperlink_click ();
        setup_hyperlink_tooltip ();

        var style_manager = Adw.StyleManager.get_default ();
        style_manager_handler_id = style_manager.notify["dark"].connect (() => {
            update_entry_style_scheme ();
        });

        var today = Date ();
        today.set_time_t (time_t ());
        select_date (today);

        if (events_expander != null && events_list_view != null && events_count_label != null) {
#if HAVE_EVOLUTION
            events_provider = new EvolutionEventsProvider ();
            events_expander.visible = true;
            update_past_events ();
#else
            events_expander.visible = false;
#endif
        }
    }

    void update_window_title () {
        var dt = new DateTime.local (current_date.get_year (), current_date.get_month (), current_date.get_day (), 0, 0, 0);
        string date_str;
        if (dt != null) {
            // Translators: This is a strftime()-like format string for the date displayed in the window title.
            date_str = dt.format (_("%A, %e %B %Y"));
        } else {
            date_str = "%04d-%02d-%02d".printf (current_date.get_year (), current_date.get_month (), current_date.get_day ());
        }

        title = date_str;
    }

    void update_entry_style_scheme () {
        var buffer = (GtkSource.Buffer?) entry_view.buffer;
        if (buffer == null)
            return;

        var style_manager = Adw.StyleManager.get_default ();
        var prefer_dark = style_manager.dark;

        var scheme_id = prefer_dark ? "Adwaita-dark" : "Adwaita";
        var scheme_manager = GtkSource.StyleSchemeManager.get_default ();
        var scheme = scheme_manager.get_scheme (scheme_id);
        if (scheme != null)
            buffer.style_scheme = scheme;
    }

    void ensure_entry_buffer_tags (Gtk.TextBuffer buffer) {
        var table = buffer.tag_table;
        if (table.lookup ("bold") == null) {
            buffer.create_tag ("bold", "weight", Pango.Weight.BOLD, null);
            buffer.create_tag ("italic", "style", Pango.Style.ITALIC, null);
            buffer.create_tag ("underline", "underline", Pango.Underline.SINGLE, null);
        }
    }

    void add_window_actions () {
        var bold_act = new GLib.SimpleAction.stateful ("bold", null, false);
        bold_act.activate.connect ((a, p) => {
            var state = p != null ? p.get_boolean () : !((GLib.SimpleAction) a).get_state ().get_boolean ();
            ((GLib.SimpleAction) a).set_state (state);
            apply_formatting ("bold", state);
        });
        add_action (bold_act);

        var italic_act = new GLib.SimpleAction.stateful ("italic", null, false);
        italic_act.activate.connect ((a, p) => {
            var state = p != null ? p.get_boolean () : !((GLib.SimpleAction) a).get_state ().get_boolean ();
            ((GLib.SimpleAction) a).set_state (state);
            apply_formatting ("italic", state);
        });
        add_action (italic_act);

        var underline_act = new GLib.SimpleAction.stateful ("underline", null, false);
        underline_act.activate.connect ((a, p) => {
            var state = p != null ? p.get_boolean () : !((GLib.SimpleAction) a).get_state ().get_boolean ();
            ((GLib.SimpleAction) a).set_state (state);
            apply_formatting ("underline", state);
        });
        add_action (underline_act);

        var cut_act = new GLib.SimpleAction ("cut", null);
        cut_act.activate.connect ((a, p) => entry_view.cut_clipboard ());
        add_action (cut_act);

        var copy_act = new GLib.SimpleAction ("copy", null);
        copy_act.activate.connect ((a, p) => entry_view.copy_clipboard ());
        add_action (copy_act);

        var paste_act = new GLib.SimpleAction ("paste", null);
        paste_act.activate.connect ((a, p) => paste_from_clipboard ());
        add_action (paste_act);

        var insert_time_act = new GLib.SimpleAction ("insert-time", null);
        insert_time_act.activate.connect ((a, p) => insert_time ());
        add_action (insert_time_act);

        var hyperlink_act = new GLib.SimpleAction ("hyperlink", null);
        hyperlink_act.activate.connect ((a, p) => hyperlink_toggle ());
        add_action (hyperlink_act);

        var important_act = new GLib.SimpleAction.stateful ("important", null, false);
        important_act.activate.connect ((a, p) => {
            var state = p != null ? p.get_boolean () : !((GLib.SimpleAction) a).get_state ().get_boolean ();
            ((GLib.SimpleAction) a).set_state (state);
            set_important (state);
        });
        add_action (important_act);

        var show_tags_act = new GLib.SimpleAction.stateful ("show-tags", null, false);
        show_tags_act.activate.connect ((a, p) => {
            var state = p != null ? p.get_boolean () : !((GLib.SimpleAction) a).get_state ().get_boolean ();
            ((GLib.SimpleAction) a).set_state (state);
            if (entry_tags_area != null) {
                entry_tags_area.visible = state;
            }
        });
        add_action (show_tags_act);

        var select_date_act = new GLib.SimpleAction ("select-date", null);
        select_date_act.activate.connect ((a, p) => show_date_picker ());
        add_action (select_date_act);
    }

    void show_date_picker () {
        if (calendar_button != null) {
            calendar_button.popdown ();
        }
        var dialog = new DateEntryDialog ();
        dialog.date = current_date;
        dialog.done.connect ((d) => {
            if (d != null)
                select_date (d);
        });
        dialog.present (this);
    }

    void on_calendar_day_selected () {
        if (calendar_button != null) {
            select_date (calendar_button.get_date ());
        }
    }

    void setup_hyperlink_tooltip () {
        var motion = new Gtk.EventControllerMotion ();
        motion.motion.connect ((x, y) => {
            var buffer = (Gtk.TextBuffer?) entry_view.buffer;
            if (buffer == null) {
                entry_view.set_tooltip_text (null);
                return;
            }

            int bx, by;
            entry_view.window_to_buffer_coords (Gtk.TextWindowType.WIDGET, (int) x, (int) y, out bx, out by);
            int trailing;
            Gtk.TextIter iter;
            if (!entry_view.get_iter_at_position (out iter, out trailing, bx, by)) {
                entry_view.set_tooltip_text (null);
                return;
            }

            HyperlinkTag? link_tag = null;
            iter.get_tags ().foreach ((tag) => {
                if (link_tag == null)
                    link_tag = tag as HyperlinkTag;
            });

            if (link_tag != null)
                entry_view.set_tooltip_text (link_tag.uri);
            else
                entry_view.set_tooltip_text (null);
        });

        entry_view.add_controller (motion);
    }

    Gee.ArrayList<EntryLink> collect_hyperlinks (Gtk.TextBuffer buffer) {
        var links = new Gee.ArrayList<EntryLink> ();

        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);

        var iter = start;
        while (iter.compare (end) < 0) {
            HyperlinkTag? link_tag = null;
            iter.get_tags ().foreach ((tag) => {
                if (link_tag == null)
                    link_tag = tag as HyperlinkTag;
            });

            if (link_tag != null) {
                Gtk.TextIter range_start = iter;
                Gtk.TextIter range_end = iter;

                range_start.backward_to_tag_toggle (link_tag);
                range_end.forward_to_tag_toggle (link_tag);

                int start_offset = range_start.get_offset ();
                int end_offset = range_end.get_offset ();

                links.add (new EntryLink (start_offset, end_offset, link_tag.uri));

                iter = range_end;
            } else {
                if (!iter.forward_char ())
                    break;
            }
        }

        return links;
    }

    void apply_formatting (string tag_name, bool applying) {
        if (updating_formatting)
            return;
        var buffer = (Gtk.TextBuffer?) entry_view.buffer;
        if (buffer == null)
            return;
        Gtk.TextIter start, end;
        if (!buffer.get_selection_bounds (out start, out end))
            return;
        if (applying)
            buffer.apply_tag_by_name (tag_name, start, end);
        else
            buffer.remove_tag_by_name (tag_name, start, end);
    }

    void set_important (bool important) {
        if (current_entry == null)
            return;
        current_entry.important = important;
        save_current_entry ();
    }

    void insert_time () {
        var buffer = (Gtk.TextBuffer?) entry_view.buffer;
        if (buffer == null)
            return;
        var now = new DateTime.now_local ();
        var time_str = now.format ("%Y-%m-%d %H:%M");
        Gtk.TextIter iter;
        buffer.get_iter_at_mark (out iter, buffer.get_insert ());
        buffer.insert (ref iter, time_str, time_str.length);
    }

    void setup_spellchecking () {
        if (spell_setup)
            return;

        var buffer = (GtkSource.Buffer?) entry_view.buffer;
        if (buffer == null)
            return;

        spell_checker = Spelling.Checker.get_default ();
        if (spell_checker == null)
            return;

        spell_adapter = new Spelling.TextBufferAdapter (buffer, spell_checker);

        // Hook up context menu actions for corrections
        var menu_model = spell_adapter.get_menu_model ();
        if (menu_model != null)
            entry_view.extra_menu = menu_model;
        entry_view.insert_action_group ("spelling", spell_adapter);

        // Apply settings
        var s = new GLib.Settings ("org.gnome.almanah");
        var lang = s.get_string ("spelling-language");
        if (lang == null || lang.strip () == "") {
            var env_lang = Environment.get_variable ("LANG");
            if (env_lang != null && env_lang.length > 0)
                lang = env_lang.split (".")[0];
            if (lang == null || lang.strip () == "")
                lang = "en";
        }
        spell_adapter.language = lang.strip ();

        spell_adapter.enabled = s.get_boolean ("spell-checking-enabled");

        // React to settings changes
        s.changed["spell-checking-enabled"].connect (() => {
            if (spell_adapter != null)
                spell_adapter.enabled = s.get_boolean ("spell-checking-enabled");
        });
        s.changed["spelling-language"].connect (() => {
            if (spell_adapter != null) {
                var new_lang = s.get_string ("spelling-language");
                if (new_lang != "")
                    spell_adapter.language = new_lang;
            }
        });

        spell_setup = true;
    }

    static string? normalize_pasted_uri (string text) {
        var t = text.strip ();
        if (t.length == 0)
            return null;
        var first_line = t.split ("\n")[0].strip ();
        if (first_line.length == 0)
            return null;
        if (Uri.parse_scheme (first_line) != null)
            return first_line;
        if (first_line.has_prefix ("www."))
            return "https://" + first_line;
        return null;
    }

    void paste_from_clipboard () {
        var display = Gdk.Display.get_default ();
        if (display == null) {
            entry_view.paste_clipboard ();
            return;
        }
        var clipboard = display.get_clipboard ();
        clipboard.read_text_async.begin (null, (obj, res) => {
            string? text = null;
            try {
                text = clipboard.read_text_async.end (res);
            } catch (Error e) {
                entry_view.paste_clipboard ();
                return;
            }
            var uri = normalize_pasted_uri (text ?? "");
            var buffer = (Gtk.TextBuffer?) entry_view.buffer;
            if (buffer != null && uri != null) {
                Gtk.TextIter iter;
                buffer.get_iter_at_mark (out iter, buffer.get_insert ());
                var tag = new HyperlinkTag (uri);
                buffer.get_tag_table ().add (tag);
                Gtk.TextIter start_iter = iter;
                buffer.insert (ref iter, uri, uri.length);
                buffer.apply_tag (tag, start_iter, iter);
            } else {
                entry_view.paste_clipboard ();
            }
        });
    }

    void setup_hyperlink_click () {
        var gesture = new Gtk.GestureClick ();
        gesture.button = Gdk.BUTTON_PRIMARY;
        gesture.pressed.connect ((n_press, x, y) => {
            var mods = gesture.get_current_event_state ();
            if ((mods & Gdk.ModifierType.CONTROL_MASK) == 0)
                return;
            var buffer = (Gtk.TextBuffer?) entry_view.buffer;
            if (buffer == null)
                return;
            int bx, by;
            entry_view.window_to_buffer_coords (Gtk.TextWindowType.WIDGET, (int) x, (int) y, out bx, out by);
            int trailing;
            Gtk.TextIter iter;
            if (!entry_view.get_iter_at_position (out iter, out trailing, bx, by))
                return;
            HyperlinkTag? link_tag = null;
            iter.get_tags ().foreach ((tag) => {
                if (link_tag == null)
                    link_tag = tag as HyperlinkTag;
            });
            if (link_tag != null)
                open_uri (link_tag.uri);
        });
        entry_view.add_controller (gesture);
    }

    void open_uri (string uri) {
        var launcher = new Gtk.UriLauncher (uri);
        launcher.launch.begin (this, null, (obj, res) => {
            try {
                launcher.launch.end (res);
            } catch (Error e) {
                warning ("Failed to open URI: %s", e.message);
            }
        });
    }

    void hyperlink_toggle () {
        var buffer = (Gtk.TextBuffer?) entry_view.buffer;
        if (buffer == null)
            return;
        Gtk.TextIter start, end;
        if (!buffer.get_selection_bounds (out start, out end)) {
            return;
        }
        HyperlinkTag? existing = null;
        start.get_tags ().foreach ((tag) => {
            if (existing == null)
                existing = tag as HyperlinkTag;
        });
        bool in_link = existing != null;
        if (in_link && existing != null) {
            buffer.remove_tag (existing, start, end);
            return;
        }
        var dialog = new UriEntryDialog ();
        dialog.done.connect ((uri) => {
            if (uri == null || uri.length == 0)
                return;
            if (!buffer.get_selection_bounds (out start, out end))
                return;
            var tag = new HyperlinkTag (uri);
            buffer.get_tag_table ().add (tag);
            buffer.apply_tag (tag, start, end);
        });
        dialog.present (this);
    }

    void setup_events_list () {
        if (events_expander == null || events_list_view == null || events_count_label == null)
            return;
        events_strings = new Gtk.StringList ({});
        events_selection = new Gtk.SingleSelection (events_strings);
        events_list_view.model = events_selection;
        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect ((obj, item) => {
            ((Gtk.ListItem) item).child = new Gtk.Label ("") { xalign = 0 };
        });
        factory.bind.connect ((obj, item) => {
            var li = (Gtk.ListItem) item;
            var label = (Gtk.Label) li.child;
            var s = (string?) li.item;
            label.label = s ?? "";
        });
        events_list_view.factory = factory;
        events_count_label.label = "0";
    }

    void update_past_events () {
        if (events_strings == null || events_selection == null)
            return;

        // Clear existing items.
        while (events_strings.get_n_items () > 0) {
            events_strings.remove (0);
        }
        events_count_label.label = "0";

        if (events_provider == null || !events_provider.available)
            return;

        var events = events_provider.get_past_events (current_date, 30);
        foreach (var e in events) {
            events_strings.append (e);
        }
        events_count_label.label = ((int) events.size).to_string ();
    }

    [GtkCallback]
    bool mw_delete_event_cb () {
        save_current_entry ();
        return false;
    }

    public void select_date (Date date) {
        save_current_entry ();

        current_date = date;
        var model_entry = storage_manager != null ? storage_manager.get_entry (date) : null;

        if (model_entry != null) {
            current_entry = new Entry (date);
            current_entry.content = model_entry.content;
            current_entry.important = model_entry.important;
            current_entry.last_edited = model_entry.last_edited;
        } else {
            current_entry = new Entry (date);
        }

        var buffer = (GtkSource.Buffer) entry_view.buffer;
        if (buffer == null) {
            buffer = new GtkSource.Buffer (null);
            entry_view.buffer = buffer;
        }
        ensure_entry_buffer_tags (buffer);
        buffer.text = current_entry.content;

        // Re-apply stored hyperlink tags, if any.
        if (current_entry.links != null && current_entry.links.size > 0) {
            foreach (var link in current_entry.links) {
                var tag = new HyperlinkTag (link.uri);
                buffer.get_tag_table ().add (tag);
                Gtk.TextIter link_start;
                Gtk.TextIter link_end;
                buffer.get_iter_at_offset (out link_start, link.start_offset);
                buffer.get_iter_at_offset (out link_end, link.end_offset);
                buffer.apply_tag (tag, link_start, link_end);
            }
        }

        setup_spellchecking ();

        update_entry_style_scheme ();

        var important_act = lookup_action ("important") as GLib.SimpleAction?;
        if (important_act != null)
            important_act.set_state (current_entry.important);

        if (entry_tags_area != null) {
            entry_tags_area.entry = current_entry;
        }

        update_past_events ();

        update_window_title ();

        if (calendar_button != null) {
            calendar_button.select_date (current_date);
        }
    }

    void save_current_entry () {
        if (current_entry == null || storage_manager == null)
            return;

        var buffer = (GtkSource.Buffer?) entry_view.buffer;
        if (buffer != null) {
            current_entry.content = buffer.text;
            current_entry.links = collect_hyperlinks (buffer);
            try {
                storage_manager.set_entry (current_entry);
            } catch (Error e) {
                warning ("Failed to save entry: %s", e.message);
            }
        }
    }

    public void print_entry () {
        save_current_entry ();

        var buffer = (GtkSource.Buffer?) entry_view.buffer;
        var text = buffer != null ? buffer.text : "";
        var date_str = "%04d-%02d-%02d".printf (current_date.get_year (), current_date.get_month (), current_date.get_day ());
        var title = _ ("Almanah Diary – %s").printf (date_str);

        var op = new Gtk.PrintOperation ();
        op.n_pages = 1;
        op.unit = Gtk.Unit.MM;
        op.embed_page_setup = true;

        op.draw_page.connect ((op, context, page_nr) => {
            var cr = context.get_cairo_context ();
            var layout = context.create_pango_layout ();
            layout.set_width ((int) (context.get_width () * Pango.SCALE));
            layout.set_wrap (Pango.WrapMode.WORD_CHAR);

            var margin = 20.0;
            var y = margin;

            var header = "%s\n\n".printf (title);
            layout.set_text (header, -1);
            cr.move_to (margin, y);
            pango_cairo_show_layout (cr, layout);

            Pango.Rectangle ink, logical;
            layout.get_extents (out ink, out logical);
            y += logical.height / Pango.SCALE;

            layout.set_text (text, -1);
            cr.move_to (margin, y);
            pango_cairo_show_layout (cr, layout);
        });

        try {
            var result = op.run (Gtk.PrintOperationAction.PRINT_DIALOG, this);
            if (result == Gtk.PrintOperationResult.ERROR) {
                warning ("Print failed");
            }
        } catch (GLib.Error e) {
            warning ("Print error: %s", e.message);
        }
    }
}

}

