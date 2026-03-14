// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using Adw;
using GLib;

namespace Almanah {

[GtkTemplate (ui = "/io/github/dimmus/almanah/ui/preferences-dialog.ui")]
public class PreferencesDialog : Adw.PreferencesDialog {
    [GtkChild] unowned Gtk.DropDown key_combo;
    [GtkChild] unowned Gtk.CheckButton spell_checking_enabled_check_button;

    private GLib.Settings settings;
    private string[] key_ids = {};
    private ulong key_combo_selected_handler_id = 0;

    public PreferencesDialog (GLib.Settings settings) {
        this.settings = settings;

        title = _("Preferences");

        settings.bind ("spell-checking-enabled", spell_checking_enabled_check_button, "active", GLib.SettingsBindFlags.DEFAULT);

        load_encryption_keys ();
    }

    private void load_encryption_keys () {
        string[] ids = {};
        string[] labels = {};

        /* Always offer the option to disable encryption. */
        ids += "";
        labels += _("None (don't encrypt)");

        try {
            string stdout_str;
            string stderr_str;
            int exit_status;

            Process.spawn_sync (
                null,
                {"gpg", "--with-colons", "--list-secret-keys"},
                null,
                SpawnFlags.SEARCH_PATH,
                null,
                out stdout_str,
                out stderr_str,
                out exit_status
            );

            if (exit_status == 0) {
                string? pending_keyid = null;

                foreach (unowned string line in stdout_str.split ("\n")) {
                    if (line == "")
                        continue;

                    string[] fields = line.split (":");
                    if (fields.length == 0)
                        continue;

                    unowned string rec_type = fields[0];

                    if ((rec_type == "sec" || rec_type == "ssb") && fields.length > 4) {
                        /* Primary or subkey record; remember key ID until we see a UID. */
                        pending_keyid = fields[4];
                    } else if (rec_type == "uid" && pending_keyid != null) {
                        string uid_label = fields.length > 9 && fields[9] != "" ? fields[9] : pending_keyid;
                        string id = "openpgp:%s".printf (pending_keyid);
                        ids += id;
                        labels += uid_label;
                        pending_keyid = null;
                    }
                }
            }
        } catch (Error e) {
            /* If GPG is unavailable, fall back to just the “None” option. */
        }

        key_ids = ids;

        var string_list = new Gtk.StringList (labels);
        key_combo.model = string_list;

        /* Select the key currently stored in settings, if any. */
        string current_id = settings.get_string ("encryption-key");
        uint active = 0;
        if (current_id != "") {
            for (uint i = 0; i < key_ids.length; i++) {
                if (key_ids[i] == current_id) {
                    active = i;
                    break;
                }
            }
        }
        key_combo.selected = active;

        if (key_combo_selected_handler_id != 0) {
            key_combo.disconnect (key_combo_selected_handler_id);
        }

        key_combo_selected_handler_id = key_combo.notify["selected"].connect (() => {
            uint index = key_combo.selected;
            if (index >= key_ids.length)
                return;

            string id = key_ids[index];
            settings.set_string ("encryption-key", id);
        });
    }

    [GtkCallback]
    void pd_new_key_button_clicked_cb () {
        try {
            Pid child_pid;
            Process.spawn_async_with_pipes (
                null,
                {"seahorse"},
                null,
                SpawnFlags.SEARCH_PATH,
                null,
                out child_pid,
                null,
                null,
                null
            );

            ChildWatch.add (child_pid, (pid, status) => {
                Idle.add (() => {
                    load_encryption_keys ();
                    return false;
                });
            });
        } catch (Error e) {
            var dialog = new Adw.AlertDialog (
                _("Error opening Seahorse"),
                e.message
            );
            dialog.present (this);
        }
    }
}

}
