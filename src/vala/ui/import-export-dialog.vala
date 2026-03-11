// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using Adw;
using GLib;

namespace Almanah {

public enum ImportExportMode {
    TEXT_FILES = 0,
    DATABASE = 1
}

public class ImportExportDialog : Adw.Dialog {
    private Gtk.DropDown mode_dropdown;
    private Gtk.Button path_button;
    private Gtk.Button apply_btn;
    private Gtk.Label description_label;
    private Gtk.ProgressBar progress_bar;

    public StorageManager storage_manager { get; construct; }
    public bool import_mode { get; construct; }

    private ImportExportMode current_mode = ImportExportMode.TEXT_FILES;
    private File? target = null;
    private uint progress_pulse_id = 0;
    private ImportExportOperations? _ops = null;  /* keep ref during async op */

    public ImportExportDialog (StorageManager storage_manager, bool import_mode) {
        Object (
            storage_manager: storage_manager,
            import_mode: import_mode
        );
    }

    construct {
        title = import_mode ? _("Import") : _("Export");
        content_width = 480;

        var page = new Adw.PreferencesPage ();
        var group = new Adw.PreferencesGroup ();

        var mode_row = new Adw.ActionRow () {
            title = _("Format")
        };
        var labels = new string[] { _("Text files"), _("Database") };
        mode_dropdown = new Gtk.DropDown.from_strings (labels);
        mode_dropdown.selected = 0;
        mode_row.add_suffix (mode_dropdown);
        group.add (mode_row);

        var path_row = new Adw.ActionRow () {
            title = _("Location")
        };
        path_button = new Gtk.Button.with_label (_("Select…"));
        path_row.add_suffix (path_button);
        group.add (path_row);

        var desc_row = new Adw.ActionRow () {
            title = _("Details")
        };
        description_label = new Gtk.Label ("") {
            wrap = true,
            xalign = 0
        };
        desc_row.add_suffix (description_label);
        group.add (desc_row);

        page.add (group);

        var progress_group = new Adw.PreferencesGroup ();
        progress_bar = new Gtk.ProgressBar () {
            hexpand = true,
            fraction = 0.0
        };
        progress_group.add (progress_bar);
        page.add (progress_group);

        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 12,
            margin_bottom = 12
        };
        content.append (page);

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.END,
            margin_top = 12
        };
        var cancel_btn = new Gtk.Button.with_mnemonic (_("_Cancel"));
        cancel_btn.clicked.connect (() => close ());
        apply_btn = new Gtk.Button.with_mnemonic (import_mode ? _("_Import") : _("_Export"));
        apply_btn.add_css_class ("suggested-action");
        apply_btn.clicked.connect (on_apply_clicked);
        button_box.append (cancel_btn);
        button_box.append (apply_btn);
        content.append (button_box);

        child = content;

        mode_dropdown.notify["selected"].connect (mode_dropdown_selected_changed_cb);
        path_button.clicked.connect (path_button_clicked_cb);

        mode_dropdown_selected_changed_cb ();
    }

    void mode_dropdown_selected_changed_cb () {
        current_mode = (ImportExportMode) mode_dropdown.selected;
        target = null;
        path_button.label = _("Select…");
        update_description ();
    }

    void update_description () {
        if (import_mode) {
            if (current_mode == ImportExportMode.TEXT_FILES) {
                description_label.label = _("Select a folder containing text files, one per entry, with names in the format \"yyyy-mm-dd\", and no extension. Any and all such files will be imported.");
            } else {
                description_label.label = _("Select a database file created by Almanah Diary to import.");
            }
        } else {
            if (current_mode == ImportExportMode.TEXT_FILES) {
                description_label.label = _("Select a folder to export all entries as plain text files.");
            } else {
                description_label.label = _("Select a filename for an unencrypted copy of the diary database.");
            }
        }
    }

    void path_button_clicked_cb () {
        var parent = root as Gtk.Window;
        var dialog = new Gtk.FileDialog ();

        if (import_mode) {
            if (current_mode == ImportExportMode.TEXT_FILES) {
                dialog.select_folder.begin (parent, null, (obj, res) => {
                    try {
                        var folder = dialog.select_folder.end (res);
                        if (folder != null) {
                            target = folder;
                            path_button.label = folder.get_parse_name ();
                        }
                    } catch (GLib.Error e) {
                        if (!(e is IOError.CANCELLED))
                            warning ("Select folder failed: %s", e.message);
                    }
                });
            } else {
                dialog.open.begin (parent, null, (obj, res) => {
                    try {
                        var file = dialog.open.end (res);
                        if (file != null) {
                            target = file;
                            path_button.label = file.get_parse_name ();
                        }
                    } catch (GLib.Error e) {
                        if (!(e is IOError.CANCELLED))
                            warning ("Open file failed: %s", e.message);
                    }
                });
            }
        } else {
            if (current_mode == ImportExportMode.TEXT_FILES) {
                dialog.select_folder.begin (parent, null, (obj, res) => {
                    try {
                        var folder = dialog.select_folder.end (res);
                        if (folder != null) {
                            target = folder;
                            path_button.label = folder.get_parse_name ();
                        }
                    } catch (GLib.Error e) {
                        if (!(e is IOError.CANCELLED))
                            warning ("Select folder failed: %s", e.message);
                    }
                });
            } else {
                dialog.save.begin (parent, null, (obj, res) => {
                    try {
                        var file = dialog.save.end (res);
                        if (file != null) {
                            target = file;
                            path_button.label = file.get_parse_name ();
                        }
                    } catch (GLib.Error e) {
                        if (!(e is IOError.CANCELLED))
                            warning ("Save file failed: %s", e.message);
                    }
                });
            }
        }
    }

    void on_apply_clicked () {
        if (target == null)
            return;

        apply_btn.sensitive = false;
        progress_bar.fraction = 0.0;
        stop_progress_pulse ();

        _ops = new ImportExportOperations (storage_manager);
        _ops.finished.connect (on_operation_finished);

        if (import_mode) {
            if (current_mode == ImportExportMode.TEXT_FILES) {
                _ops.import_text_files_async (target);
            } else {
                _ops.import_database_async (target);
            }
        } else {
            if (current_mode == ImportExportMode.TEXT_FILES) {
                _ops.export_text_files_async (target);
            } else {
                _ops.export_database_async (target);
            }
        }

        progress_pulse_id = Timeout.add (50, () => {
            progress_bar.pulse ();
            return true;
        });
    }

    void stop_progress_pulse () {
        if (progress_pulse_id != 0) {
            Source.remove (progress_pulse_id);
            progress_pulse_id = 0;
        }
    }

    void on_operation_finished (bool success, string? error_message) {
        stop_progress_pulse ();
        _ops = null;
        apply_btn.sensitive = true;

        var alert = new Adw.AlertDialog (
            success ? (import_mode ? _("Import complete") : _("Export complete")) : _("Error"),
            success
                ? (import_mode ? _("Entries have been imported.") : _("Entries have been exported."))
                : (error_message ?? _("An unknown error occurred"))
        );
        alert.add_response ("ok", _("OK"));
        alert.set_default_response ("ok");
        alert.set_close_response ("ok");
        alert.choose.begin (root as Gtk.Widget, null, (obj, res) => {
            alert.choose.end (res);
            close ();
        });
    }
}

}
