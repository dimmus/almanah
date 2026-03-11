// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Adw;
using Gtk;

namespace Almanah {

public class Application : Adw.Application {
    private StorageManager? storage_manager;
    private GLib.Settings settings;
    private MainWindow? main_window;
    private bool debug_logging = false;

    // Call C API directly to avoid Vala deprecation warning on Gtk.StyleContext class.
    [CCode (cname = "gtk_style_context_add_provider_for_display")]
    extern static void add_css_provider_for_display (Gdk.Display display, Gtk.StyleProvider provider, uint priority);

    public Application () {
        Object (
            application_id: "org.gnome.Almanah",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );

        // Add legacy-style --debug option to control verbose logging.
        var entries = new OptionEntry[2];
        entries[0].long_name = "debug";
        entries[0].short_name = 0;
        entries[0].flags = 0;
        entries[0].arg = OptionArg.NONE;
        entries[0].arg_data = (void*) &debug_logging;
        entries[0].description = _("Enable debug mode");
        entries[0].arg_description = null;

        add_main_option_entries (entries);
        set_option_context_summary (_("Manage your diary. Only one instance of the program may be open at any time."));
    }

    protected override void startup () {
        base.startup ();

        // Global log filter: silence a few known noisy warnings while keeping
        // everything else going through the default handler.
        Log.set_default_handler ((domain, level, message) => {
            if (domain == "libenchant" &&
                (level & LogLevelFlags.LEVEL_WARNING) != 0 &&
                message != null &&
                message.index_of ("Error loading plugin:") >= 0) {
                return; // ignore missing enchant backends
            }

            if (domain == "Gtk" &&
                (level & LogLevelFlags.LEVEL_WARNING) != 0 &&
                message != null &&
                message.index_of ("Broken accounting of active state") >= 0) {
                return; // ignore upstream GTK active-state warnings
            }

            Log.default_handler (domain, level, message);
        });

        settings = new GLib.Settings ("org.gnome.almanah");

        if (debug_logging) {
            Log.set_handler (null, LogLevelFlags.LEVEL_DEBUG, (domain, level, message) => {
                Log.default_handler (domain, level, message);
            });
        }

        // Application CSS (tags etc.) from resources
        var css = new Gtk.CssProvider ();
        css.load_from_resource ("/org/gnome/Almanah/css/almanah.css");
        var display = Gdk.Display.get_default ();
        if (display != null) {
            add_css_provider_for_display (display, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        var data_dir = Environment.get_user_data_dir ();
        var db_path = Path.build_filename (data_dir, "almanah", "diary.db");

        var dir = Path.get_dirname (db_path);
        if (DirUtils.create_with_parents (dir, 0700) != 0) {
            warning ("Could not create data directory: %s: %m", dir);
        }

        storage_manager = new StorageManager (db_path, settings);
        Error? err = null;
        if (!storage_manager.open (out err)) {
            critical ("Error opening database: %s", err != null ? err.message : _("Unknown error"));
            storage_manager = null;
            return;
        }

        var search_action = new SimpleAction ("search", null);
        search_action.activate.connect (action_search_cb);
        add_action (search_action);

        var preferences_action = new SimpleAction ("preferences", null);
        preferences_action.activate.connect (action_preferences_cb);
        add_action (preferences_action);

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (action_quit_cb);
        add_action (quit_action);

        var import_action = new SimpleAction ("import", null);
        import_action.activate.connect (action_import_cb);
        add_action (import_action);

        var export_action = new SimpleAction ("export", null);
        export_action.activate.connect (action_export_cb);
        add_action (export_action);

        var print_action = new SimpleAction ("print", null);
        print_action.activate.connect (action_print_cb);
        add_action (print_action);

        var about_action = new SimpleAction ("about", null);
        about_action.activate.connect (action_about_cb);
        add_action (about_action);

        set_accels_for_action ("app.search", {"<Ctrl>f"});
        set_accels_for_action ("app.quit", {"<Ctrl>q"});
        set_accels_for_action ("win.select-date", {"<Ctrl>d"});
        set_accels_for_action ("win.paste", {"<Ctrl>v"});
    }

    protected override void activate () {
        base.activate ();

        if (main_window == null) {
            main_window = new MainWindow (this);
            main_window.init_with_storage (storage_manager);
        }

        main_window.present ();
    }

    void action_search_cb (SimpleAction action, Variant? parameter) {
        if (main_window == null || storage_manager == null)
            return;

        var dialog = new SearchDialog (storage_manager, main_window);
        dialog.present (main_window);
    }

    void action_preferences_cb (SimpleAction action, Variant? parameter) {
        var dialog = new PreferencesDialog (settings);
        dialog.present (main_window);
    }

    void action_quit_cb (SimpleAction action, Variant? parameter) {
        if (storage_manager != null)
            storage_manager.close ();
        quit ();
    }

    void action_import_cb (SimpleAction action, Variant? parameter) {
        if (main_window == null || storage_manager == null)
            return;
        var dialog = new ImportExportDialog (storage_manager, true);
        dialog.present (main_window);
    }

    void action_export_cb (SimpleAction action, Variant? parameter) {
        if (main_window == null || storage_manager == null)
            return;
        var dialog = new ImportExportDialog (storage_manager, false);
        dialog.present (main_window);
    }

    void action_print_cb (SimpleAction action, Variant? parameter) {
        if (main_window == null)
            return;
        main_window.print_entry ();
    }

    void action_about_cb (SimpleAction action, Variant? parameter) {
        var about = new Adw.AboutDialog ();
        about.application_icon = "org.gnome.Almanah";
        about.application_name = _ ("Almanah Diary");
        about.developer_name = "Almanah Developers";
        about.version = PROJECT_VERSION;
        about.website = "https://wiki.gnome.org/Apps/Almanah_Diary";
        about.license_type = Gtk.License.GPL_3_0;
        about.developers = {
            "Philip Withnall <philip@tecnocode.co.uk>",
            "Jan Tojnar <jtojnar@gmail.com>",
            "Dmitri Chudinov <dmitri.chudinov@gmail.com>"
        };

        string comments;
        if (storage_manager != null) {
            var entries = storage_manager.get_all_entries ();
            comments = _ ("A helpful diary keeper, storing %u entries.").printf ((uint) entries.size);
        } else {
            comments = _ ("A helpful diary keeper.");
        }
        about.comments = comments;

        about.present (main_window);
    }

    protected override void shutdown () {
        if (storage_manager != null) {
            storage_manager.close ();
            storage_manager = null;
        }
        base.shutdown ();
    }
}

}
