// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Gee;

[CCode (cname = "chmod", cheader_filename = "sys/stat.h")]
extern int chmod (string path, int mode);

namespace Almanah {

public errordomain ImportExportError {
    FILE_NOT_FOUND,
    READ_FAILED,
    WRITE_FAILED,
    INVALID_FORMAT,
    CANCELLED
}

public class ImportExportOperations : Object {
    public StorageManager storage_manager { get; construct; }

    public signal void progress (string? message);
    public signal void finished (bool success, string? error_message);

    public ImportExportOperations (StorageManager storage_manager) {
        Object (storage_manager: storage_manager);
    }

    public void import_text_files_async (File folder) {
        new Thread<void> ("import-text", () => {
            Error? err = null;
            try {
                import_text_files_sync (folder);
            } catch (Error e) {
                err = e;
            }
            var e = err;
            Idle.add (() => {
                finished (e == null, e?.message);
                return false;
            });
        });
    }

    void import_text_files_sync (File folder) throws Error {
        var path = folder.get_path ();
        if (path == null) {
            throw new ImportExportError.FILE_NOT_FOUND ("Invalid folder path");
        }

        var enumerator = folder.enumerate_children (
            "standard::name,standard::display-name,standard::is-hidden,time::modified",
            FileQueryInfoFlags.NONE,
            null
        );

        FileInfo? info;
        while ((info = enumerator.next_file (null)) != null) {
            var name = info.get_name ();
            var hidden = info.get_is_hidden () || (name.length > 0 && name[name.length - 1] == '~');
            if (hidden) {
                continue;
            }

            Date parsed = Date ();
            parsed.set_parse (name);
            if (!parsed.valid ()) {
                continue;
            }

            var file = folder.get_child (name);
            uint8[] contents;
            if (!file.load_contents (null, out contents, null)) {
                throw new ImportExportError.READ_FAILED ("Could not read %s".printf (name));
            }

            var content_str = (string) contents;
            if (content_str.length > 0 && content_str[content_str.length - 1] == '\0') {
                content_str = content_str.substring (0, content_str.length - 1);
            }

            var entry = new Entry (parsed);
            entry.content = content_str;
            var mod_time = info.get_modification_date_time ();
            if (mod_time != null) {
                var t = mod_time.to_unix ();
                var d = Date ();
                d.set_time_t ((time_t) t);
                entry.last_edited = d;
            } else {
                entry.last_edited = parsed;
            }

            set_entry_with_merge (entry, info.get_display_name ());
            progress ("%04d-%02d-%02d".printf (parsed.get_year (), parsed.get_month (), parsed.get_day ()));
        }
    }

    public void import_database_async (File source_file) {
        new Thread<void> ("import-db", () => {
            Error? err = null;
            try {
                import_database_sync (source_file);
            } catch (Error e) {
                err = e;
            }
            var e = err;
            Idle.add (() => {
                finished (e == null, e?.message);
                return false;
            });
        });
    }

    void import_database_sync (File source_file) throws Error {
        var path = source_file.get_path ();
        if (path == null) {
            throw new ImportExportError.FILE_NOT_FOUND ("Invalid file path");
        }

        var display_name = source_file.get_basename () ?? "database";
        var entries = StorageManager.read_entries_from_database (path);

        foreach (var entry in entries) {
            set_entry_with_merge (entry, display_name);
            progress ("%04d-%02d-%02d".printf (entry.date.get_year (), entry.date.get_month (), entry.date.get_day ()));
        }
    }

    static bool date_is_before (Date a, Date b) {
        if (a.get_year () != b.get_year ()) return a.get_year () < b.get_year ();
        if (a.get_month () != b.get_month ()) return a.get_month () < b.get_month ();
        return a.get_day () < b.get_day ();
    }

    void set_entry_with_merge (Entry imported, string import_source) throws StorageError {
        var existing = storage_manager.get_entry (imported.date);
        if (existing == null) {
            storage_manager.set_entry (imported);
            return;
        }

        if (existing.content == imported.content) {
            return; /* merged, no change */
        }

        /* Append imported content with header */
        var header = "\n\n%s\n\n".printf (
            /* Translators: appended when importing an entry for a date that already has one */
            _ ("Entry imported from \"%s\":").printf (import_source)
        );
        var merged_content = existing.content + header + imported.content;
        var merged = new Entry (imported.date);
        merged.content = merged_content;
        merged.important = existing.important || imported.important;
        merged.last_edited = imported.last_edited.valid () &&
            (!existing.last_edited.valid () || date_is_before (existing.last_edited, imported.last_edited))
            ? imported.last_edited
            : existing.last_edited;

        storage_manager.set_entry (merged);
    }

    public void export_text_files_async (File folder) {
        new Thread<void> ("export-text", () => {
            Error? err = null;
            try {
                export_text_files_sync (folder);
            } catch (Error e) {
                err = e;
            }
            var e = err;
            Idle.add (() => {
                finished (e == null, e?.message);
                return false;
            });
        });
    }

    void export_text_files_sync (File folder) throws Error {
        var entries = storage_manager.get_all_entries ();

        foreach (var entry in entries) {
            if (entry.content.strip ().length == 0) {
                continue;
            }

            var filename = "%04d-%02d-%02d".printf (
                entry.date.get_year (),
                entry.date.get_month (),
                entry.date.get_day ()
            );
            var file = folder.get_child (filename);

            var data = (uint8[]) entry.content;
            var contents = data.length > 0 && data[data.length - 1] == 0
                ? data[0:data.length - 1]
                : data;
            try {
                file.replace_contents (contents, null, false, FileCreateFlags.PRIVATE | FileCreateFlags.REPLACE_DESTINATION, null);
            } catch (GLib.Error e) {
                throw new ImportExportError.WRITE_FAILED ("Could not write %s: %s".printf (filename, e.message));
            }

            var path = file.get_path ();
            if (path != null && chmod (path, 0600) != 0) {
                warning ("Could not set permissions on %s", path);
            }

            progress ("%04d-%02d-%02d".printf (entry.date.get_year (), entry.date.get_month (), entry.date.get_day ()));
        }
    }

    public void export_database_async (File dest_file) {
        new Thread<void> ("export-db", () => {
            Error? err = null;
            try {
                export_database_sync (dest_file);
            } catch (Error e) {
                err = e;
            }
            var e = err;
            Idle.add (() => {
                finished (e == null, e?.message);
                return false;
            });
        });
    }

    void export_database_sync (File dest_file) throws Error {
        var source = File.new_for_path (storage_manager.filename);
        if (!source.copy (dest_file, FileCopyFlags.OVERWRITE, null, null)) {
            throw new ImportExportError.WRITE_FAILED ("Could not copy database");
        }

        var path = dest_file.get_path ();
        if (path != null && chmod (path, 0600) != 0) {
            throw new ImportExportError.WRITE_FAILED (_ ("Error changing exported file permissions."));
        }
    }
}

}
