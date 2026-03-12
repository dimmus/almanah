// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Sqlite;

namespace Almanah {

public errordomain StorageError {
    OPENING_FILE,
    RUNNING_QUERY
}

public class StorageManager : Object {
    public string filename { get; construct; }
    public Settings settings { get; construct; }

    Database? db;

    const string ENCRYPTED_PREFIX = "ENC1:";

    public StorageManager (string filename, Settings settings) {
        Object (filename: filename, settings: settings);
    }

    public bool open (out Error? error = null) {
        error = null;
        int ec = Database.open (filename, out db);
        if (ec != Sqlite.OK || db == null) {
            var msg = db != null ? db.errmsg () : "unknown error";
            error = new StorageError.OPENING_FILE ("Could not open database \"%s\": %s", filename, msg);
            db = null;
            return false;
        }

        try {
            create_tables ();
        } catch (Error e) {
            error = e;
            return false;
        }

        return true;
    }

    public void close () {
        db = null;
    }

    void exec_simple (string sql) throws StorageError {
        if (db == null) {
            throw new StorageError.RUNNING_QUERY ("Database not connected");
        }

        string? errmsg;
        int ec = db.exec (sql, null, out errmsg);
        if (ec != Sqlite.OK) {
            throw new StorageError.RUNNING_QUERY ("Could not run query \"%s\": %s", sql, errmsg ?? "unknown error");
        }
    }

    void create_tables () throws StorageError {
        // Simplified version of the C schema, preserving column names to ease migration.
        const string[] queries = {
            "CREATE TABLE IF NOT EXISTS entries (" +
              "year INTEGER, month INTEGER, day INTEGER, " +
              "content TEXT, " +
              "is_important INTEGER DEFAULT 0, " +
              "edited_year INTEGER DEFAULT 0, " +
              "edited_month INTEGER DEFAULT 0, " +
              "edited_day INTEGER DEFAULT 0, " +
              "version INTEGER DEFAULT 1, " +
              "PRIMARY KEY (year, month, day))",
            "CREATE TABLE IF NOT EXISTS entry_tag (" +
              "year INTEGER, month INTEGER, day INTEGER, tag TEXT)",
            "CREATE INDEX IF NOT EXISTS idx_tag ON entry_tag(tag)",
            "CREATE TABLE IF NOT EXISTS entry_link (" +
              "year INTEGER, month INTEGER, day INTEGER, " +
              "start_offset INTEGER, end_offset INTEGER, uri TEXT)",
            "CREATE INDEX IF NOT EXISTS idx_entry_link_date ON entry_link(year, month, day)",
            null
        };

        foreach (var q in queries) {
            if (q == null) {
                break;
            }
            exec_simple (q);
        }
    }

    public bool[] get_month_marked_days (int year, int month) {
        int num_days = Date.get_days_in_month ((DateMonth) month, (DateYear) year);
        var days = new bool[num_days];

        if (db == null) {
            return days;
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "SELECT day FROM entries WHERE year = ?1 AND month = ?2",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return days;
        }

        stmt.bind_int (1, year);
        stmt.bind_int (2, month);

        while (stmt.step () == Sqlite.ROW) {
            int day = stmt.column_int (0);
            if (day >= 1 && day <= num_days) {
                days[day - 1] = true;
            }
        }

        return days;
    }

    public bool entry_exists (Date date) {
        if (db == null) {
            return false;
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "SELECT day FROM entries WHERE year = ?1 AND month = ?2 AND day = ?3 LIMIT 1",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return false;
        }

        stmt.bind_int (1, date.get_year ());
        stmt.bind_int (2, date.get_month ());
        stmt.bind_int (3, date.get_day ());

        bool exists = (stmt.step () == Sqlite.ROW);
        return exists;
    }

    public Entry? get_entry (Date date) {
        if (db == null) {
            return null;
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "SELECT content, is_important, edited_day, edited_month, edited_year, version " +
            "FROM entries WHERE year = ?1 AND month = ?2 AND day = ?3",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return null;
        }

        stmt.bind_int (1, date.get_year ());
        stmt.bind_int (2, date.get_month ());
        stmt.bind_int (3, date.get_day ());

        if (stmt.step () != Sqlite.ROW) {
            return null;
        }

        var entry = new Entry (date);
        entry.content = decode_content (stmt.column_text (0) ?? "");
        entry.important = stmt.column_int (1) == 1;

        var edited_day = stmt.column_int (2);
        var edited_month = stmt.column_int (3);
        var edited_year = stmt.column_int (4);

        if (Date.valid_dmy ((DateDay) edited_day, (DateMonth) edited_month, (DateYear) edited_year)) {
            Date edited = Date ();
            edited.set_dmy ((DateDay) edited_day, (DateMonth) edited_month, (DateYear) edited_year);
            entry.last_edited = edited;
        }

        // Load stored hyperlinks, if any.
        entry.links = get_entry_links (date);

        return entry;
    }

    public bool set_entry (Entry entry) throws StorageError {
        if (db == null) {
            throw new StorageError.RUNNING_QUERY ("Database not connected");
        }

        Date date = entry.date;
        bool existed_before = entry_exists (date);

        if (entry.content.strip ().length == 0) {
            // Delete the entry for an empty content.
            exec_simple ("DELETE FROM entries WHERE " +
                         "year = %d AND month = %d AND day = %d"
                         .printf (date.get_year (), date.get_month (), date.get_day ()));
            return existed_before;
        }

        // Ensure last_edited is set.
        if (!entry.last_edited.valid ()) {
            entry.last_edited = date;
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "REPLACE INTO entries " +
            "(year, month, day, content, is_important, edited_day, edited_month, edited_year, version) " +
            "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            throw new StorageError.RUNNING_QUERY ("Could not prepare REPLACE statement: %s", db.errmsg ());
        }

        stmt.bind_int (1, date.get_year ());
        stmt.bind_int (2, date.get_month ());
        stmt.bind_int (3, date.get_day ());
        stmt.bind_text (4, encode_content (entry.content));
        stmt.bind_int (5, entry.important ? 1 : 0);
        stmt.bind_int (6, entry.last_edited.get_day ());
        stmt.bind_int (7, entry.last_edited.get_month ());
        stmt.bind_int (8, entry.last_edited.get_year ());
        stmt.bind_int (9, 1); // version

        bool ok = (stmt.step () == Sqlite.DONE);
        if (!ok) {
            throw new StorageError.RUNNING_QUERY ("Could not execute REPLACE statement: %s", db.errmsg ());
        }

        // Persist hyperlink ranges associated with this entry.
        save_entry_links (entry);

        return existed_before;
    }

    public string[] get_entry_tags (Date date) {
        var tags = new Gee.ArrayList<string> ();

        if (db == null) {
            return tags.to_array ();
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "SELECT tag FROM entry_tag WHERE year = ?1 AND month = ?2 AND day = ?3 ORDER BY tag",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return tags.to_array ();
        }

        stmt.bind_int (1, date.get_year ());
        stmt.bind_int (2, date.get_month ());
        stmt.bind_int (3, date.get_day ());

        while (stmt.step () == Sqlite.ROW) {
            var tag = stmt.column_text (0);
            if (tag != null) {
                tags.add (tag);
            }
        }

        return tags.to_array ();
    }

    public void add_entry_tag (Date date, string tag) throws StorageError {
        if (db == null) {
            throw new StorageError.RUNNING_QUERY ("Database not connected");
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "INSERT INTO entry_tag (year, month, day, tag) VALUES (?1, ?2, ?3, ?4)",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            throw new StorageError.RUNNING_QUERY ("Could not prepare INSERT statement: %s", db.errmsg ());
        }

        stmt.bind_int (1, date.get_year ());
        stmt.bind_int (2, date.get_month ());
        stmt.bind_int (3, date.get_day ());
        stmt.bind_text (4, tag);

        bool ok = (stmt.step () == Sqlite.DONE);
        if (!ok) {
            throw new StorageError.RUNNING_QUERY ("Could not execute INSERT statement: %s", db.errmsg ());
        }
    }

    public Gee.ArrayList<Entry> get_all_entries () {
        var results = new Gee.ArrayList<Entry> ();

        if (db == null) {
            return results;
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "SELECT year, month, day, content, is_important, edited_day, edited_month, edited_year " +
            "FROM entries ORDER BY year DESC, month DESC, day DESC",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return results;
        }

        while (stmt.step () == Sqlite.ROW) {
            var date = Date ();
            date.set_dmy ((DateDay) stmt.column_int (2), (DateMonth) stmt.column_int (1), (DateYear) stmt.column_int (0));
            var entry = new Entry (date);
            entry.content = decode_content (stmt.column_text (3) ?? "");
            entry.important = stmt.column_int (4) == 1;
            var ed = stmt.column_int (5);
            var em = stmt.column_int (6);
            var ey = stmt.column_int (7);
            if (Date.valid_dmy ((DateDay) ed, (DateMonth) em, (DateYear) ey)) {
                var last_edited = Date ();
                last_edited.set_dmy ((DateDay) ed, (DateMonth) em, (DateYear) ey);
                entry.last_edited = last_edited;
            }
            results.add (entry);
        }

        return results;
    }

    public Gee.ArrayList<Entry> search_entries (string search_string) {
        var results = new Gee.ArrayList<Entry> ();

        if (db == null || search_string.strip () == "") {
            return results;
        }

        Statement stmt;
        string pattern = "%%%s%%".printf (search_string);
        int ec = db.prepare_v2 (
            "SELECT e.year, e.month, e.day, e.content, e.is_important, e.edited_day, e.edited_month, e.edited_year " +
            "FROM entries e " +
            "LEFT JOIN entry_tag et ON e.year=et.year AND e.month=et.month AND e.day=et.day " +
            "WHERE e.content LIKE ?1 OR et.tag LIKE ?1 " +
            "GROUP BY e.year, e.month, e.day " +
            "ORDER BY e.year DESC, e.month DESC, e.day DESC",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return results;
        }

        stmt.bind_text (1, pattern);

        while (stmt.step () == Sqlite.ROW) {
            var date = Date ();
            date.set_dmy ((DateDay) stmt.column_int (2), (DateMonth) stmt.column_int (1), (DateYear) stmt.column_int (0));
            var entry = new Entry (date);
            entry.content = decode_content (stmt.column_text (3) ?? "");
            entry.important = stmt.column_int (4) == 1;
            var ed = stmt.column_int (5);
            var em = stmt.column_int (6);
            var ey = stmt.column_int (7);
            if (Date.valid_dmy ((DateDay) ed, (DateMonth) em, (DateYear) ey)) {
                var last_edited = Date ();
                last_edited.set_dmy ((DateDay) ed, (DateMonth) em, (DateYear) ey);
                entry.last_edited = last_edited;
            }
            results.add (entry);
        }

        return results;
    }

    public string[] get_all_tags () {
        var tags = new Gee.ArrayList<string> ();

        if (db == null) {
            return tags.to_array ();
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "SELECT DISTINCT tag FROM entry_tag ORDER BY tag",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return tags.to_array ();
        }

        while (stmt.step () == Sqlite.ROW) {
            var tag = stmt.column_text (0);
            if (tag != null) {
                tags.add (tag);
            }
        }

        return tags.to_array ();
    }

    public static Gee.ArrayList<Entry> read_entries_from_database (string path) throws StorageError {
        var results = new Gee.ArrayList<Entry> ();
        Database? ext_db = null;

        int ec = Database.open (path, out ext_db);
        if (ec != Sqlite.OK || ext_db == null) {
            throw new StorageError.OPENING_FILE ("Could not open database \"%s\": %s", path,
                ext_db != null ? ext_db.errmsg () : "unknown error");
        }

        Statement stmt;
        ec = ext_db.prepare_v2 (
            "SELECT year, month, day, content, is_important, edited_day, edited_month, edited_year " +
            "FROM entries ORDER BY year DESC, month DESC, day DESC",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return results;
        }

        var settings = new Settings ("org.gnome.almanah");

        while (stmt.step () == Sqlite.ROW) {
            var date = Date ();
            date.set_dmy ((DateDay) stmt.column_int (2), (DateMonth) stmt.column_int (1), (DateYear) stmt.column_int (0));
            var entry = new Entry (date);
            entry.content = decode_content_for_settings (stmt.column_text (3) ?? "", settings);
            entry.important = stmt.column_int (4) == 1;
            var ed = stmt.column_int (5);
            var em = stmt.column_int (6);
            var ey = stmt.column_int (7);
            if (Date.valid_dmy ((DateDay) ed, (DateMonth) em, (DateYear) ey)) {
                var last_edited = Date ();
                last_edited.set_dmy ((DateDay) ed, (DateMonth) em, (DateYear) ey);
                entry.last_edited = last_edited;
            }
            results.add (entry);
        }

        return results;
    }

    string encode_content (string plain) {
        var key_id = settings.get_string ("encryption-key");
        if (key_id.strip () == "")
            return plain;

        try {
            string stdout_str;
            string stderr_str;
            int exit_status;

            string tmp_path = Path.build_filename (Environment.get_tmp_dir (), "almanah-gpg-plaintext.tmp");
            try {
                FileUtils.set_contents (tmp_path, plain);
            } catch (Error e) {
                warning ("GPG encryption: could not write temporary file: %s", e.message);
                return plain;
            }

            Process.spawn_sync (
                null,
                {
                    "gpg",
                    "--batch", "--yes",
                    "--armor",
                    "--encrypt",
                    "--trust-model", "always",
                    "--recipient", key_id,
                    "--output", "-",
                    tmp_path
                },
                null,
                SpawnFlags.SEARCH_PATH,
                null,
                out stdout_str,
                out stderr_str,
                out exit_status
            );

            FileUtils.remove (tmp_path);

            if (exit_status != 0 || stdout_str.strip () == "") {
                warning ("GPG encryption failed: %s", stderr_str.strip ());
                return plain;
            }

            return ENCRYPTED_PREFIX + stdout_str.strip ();
        } catch (Error e) {
            warning ("GPG encryption error: %s", e.message);
            return plain;
        }
    }

    string decode_content (string stored) {
        return decode_content_for_settings (stored, settings);
    }

    static string decode_content_for_settings (string stored, Settings settings) {
        if (!stored.has_prefix (ENCRYPTED_PREFIX))
            return stored;

        var key_id = settings.get_string ("encryption-key");
        if (key_id.strip () == "") {
            // No key selected anymore; show a placeholder rather than raw ciphertext.
            return _ ("[Encrypted entry – no decryption key selected]");
        }

        var armored = stored.substring (ENCRYPTED_PREFIX.length);

        try {
            string stdout_str;
            string stderr_str;
            int exit_status;

            string tmp_path = Path.build_filename (Environment.get_tmp_dir (), "almanah-gpg-ciphertext.tmp");
            try {
                FileUtils.set_contents (tmp_path, armored);
            } catch (Error e) {
                warning ("GPG decryption: could not write temporary file: %s", e.message);
                return _ ("[Encrypted entry – error during decryption]");
            }

            Process.spawn_sync (
                null,
                {
                    "gpg",
                    "--batch", "--yes",
                    "--decrypt",
                    tmp_path
                },
                null,
                SpawnFlags.SEARCH_PATH,
                null,
                out stdout_str,
                out stderr_str,
                out exit_status
            );

            FileUtils.remove (tmp_path);

            if (exit_status != 0) {
                warning ("GPG decryption failed: %s", stderr_str.strip ());
                return _ ("[Encrypted entry – failed to decrypt]");
            }

            return stdout_str;
        } catch (Error e) {
            warning ("GPG decryption error: %s", e.message);
            return _ ("[Encrypted entry – error during decryption]");
        }
    }

    public void remove_entry_tag (Date date, string tag) throws StorageError {
        if (db == null) {
            throw new StorageError.RUNNING_QUERY ("Database not connected");
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "DELETE FROM entry_tag WHERE year = ?1 AND month = ?2 AND day = ?3 AND tag = ?4",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            throw new StorageError.RUNNING_QUERY ("Could not prepare DELETE statement: %s", db.errmsg ());
        }

        stmt.bind_int (1, date.get_year ());
        stmt.bind_int (2, date.get_month ());
        stmt.bind_int (3, date.get_day ());
        stmt.bind_text (4, tag);

        bool ok = (stmt.step () == Sqlite.DONE);
        if (!ok) {
            throw new StorageError.RUNNING_QUERY ("Could not execute DELETE statement: %s", db.errmsg ());
        }
    }

    Gee.ArrayList<EntryLink> get_entry_links (Date date) {
        var links = new Gee.ArrayList<EntryLink> ();

        if (db == null) {
            return links;
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "SELECT start_offset, end_offset, uri FROM entry_link " +
            "WHERE year = ?1 AND month = ?2 AND day = ?3 " +
            "ORDER BY start_offset",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            return links;
        }

        stmt.bind_int (1, date.get_year ());
        stmt.bind_int (2, date.get_month ());
        stmt.bind_int (3, date.get_day ());

        while (stmt.step () == Sqlite.ROW) {
            int start_offset = stmt.column_int (0);
            int end_offset = stmt.column_int (1);
            string? uri = stmt.column_text (2);
            if (uri != null) {
                links.add (new EntryLink (start_offset, end_offset, uri));
            }
        }

        return links;
    }

    void clear_entry_links (Date date) throws StorageError {
        if (db == null) {
            throw new StorageError.RUNNING_QUERY ("Database not connected");
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "DELETE FROM entry_link WHERE year = ?1 AND month = ?2 AND day = ?3",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            throw new StorageError.RUNNING_QUERY ("Could not prepare DELETE statement for entry_link: %s", db.errmsg ());
        }

        stmt.bind_int (1, date.get_year ());
        stmt.bind_int (2, date.get_month ());
        stmt.bind_int (3, date.get_day ());

        bool ok = (stmt.step () == Sqlite.DONE);
        if (!ok) {
            throw new StorageError.RUNNING_QUERY ("Could not execute DELETE statement for entry_link: %s", db.errmsg ());
        }
    }

    void save_entry_links (Entry entry) throws StorageError {
        if (db == null) {
            throw new StorageError.RUNNING_QUERY ("Database not connected");
        }

        // Clear old links for the date.
        clear_entry_links (entry.date);

        if (entry.links == null || entry.links.size == 0) {
            return;
        }

        Statement stmt;
        int ec = db.prepare_v2 (
            "INSERT INTO entry_link (year, month, day, start_offset, end_offset, uri) " +
            "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            -1,
            out stmt
        );
        if (ec != Sqlite.OK) {
            throw new StorageError.RUNNING_QUERY ("Could not prepare INSERT statement for entry_link: %s", db.errmsg ());
        }

        foreach (var link in entry.links) {
            stmt.reset ();
            stmt.clear_bindings ();

            stmt.bind_int (1, entry.date.get_year ());
            stmt.bind_int (2, entry.date.get_month ());
            stmt.bind_int (3, entry.date.get_day ());
            stmt.bind_int (4, link.start_offset);
            stmt.bind_int (5, link.end_offset);
            stmt.bind_text (6, link.uri);

            bool ok = (stmt.step () == Sqlite.DONE);
            if (!ok) {
                throw new StorageError.RUNNING_QUERY ("Could not execute INSERT statement for entry_link: %s", db.errmsg ());
            }
        }
    }
}

}

