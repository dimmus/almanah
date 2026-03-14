// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Sqlite;
using Almanah;

void add_entry_model_tests () {
    Test.add_func ("/entry/constructor-sets-last-edited", () => {
        Date date = Date ();
        date.set_dmy (1, 4, 2024);
        var entry = new Entry (date);
        assert (entry.date.get_day () == 1);
        assert (entry.date.get_month () == 4);
        assert (entry.date.get_year () == 2024);
        assert (entry.last_edited.valid ());
        assert (entry.last_edited.get_day () == date.get_day ());
        assert (entry.last_edited.get_month () == date.get_month ());
        assert (entry.last_edited.get_year () == date.get_year ());
        assert (entry.content == "");
        assert (!entry.important);
    });
}

void add_entry_roundtrip_tests () {
    Test.add_func ("/storage/simple-roundtrip", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-simple.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (1, 1, 2024);

        assert (!sm.entry_exists (date));
        assert (sm.get_entry (date) == null);

        var entry = new Entry (date);
        entry.content = "Hello test";
        entry.important = true;

        bool existed_before = false;
        try {
            existed_before = sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }
        assert (!existed_before);
        assert (sm.entry_exists (date));

        var loaded = sm.get_entry (date);
        assert (loaded != null);
        assert (loaded.content == "Hello test");
        assert (loaded.important == true);

        loaded.content = "Updated";
        try {
            existed_before = sm.set_entry (loaded);
        } catch (StorageError e) {
            assert_not_reached ();
        }
        assert (existed_before);

        var loaded2 = sm.get_entry (date);
        assert (loaded2 != null);
        assert (loaded2.content == "Updated");
    });

    Test.add_func ("/storage/delete-empty", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-delete.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (2, 1, 2024);

        var entry = new Entry (date);
        entry.content = "Temp";
        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }
        assert (sm.entry_exists (date));

        entry.content = "";
        bool existed_before = false;
        try {
            existed_before = sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }
        assert (existed_before);
        assert (!sm.entry_exists (date));
        assert (sm.get_entry (date) == null);
    });

    Test.add_func ("/storage/last-edited-roundtrip", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-last-edited.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (20, 6, 2024);
        Date edited = Date ();
        edited.set_dmy (25, 6, 2024);

        var entry = new Entry (date);
        entry.content = "Edited later";
        entry.important = false;
        entry.last_edited = edited;

        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        var loaded = sm.get_entry (date);
        assert (loaded != null);
        assert (loaded.content == "Edited later");
        assert (loaded.last_edited.valid ());
        assert (loaded.last_edited.get_day () == 25);
        assert (loaded.last_edited.get_month () == 6);
        assert (loaded.last_edited.get_year () == 2024);
    });

    Test.add_func ("/storage/links-roundtrip", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-links.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (10, 3, 2024);

        var entry = new Entry (date);
        entry.content = "See https://example.com and more";
        entry.links.add (new EntryLink (4, 23, "https://example.com"));

        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        var loaded = sm.get_entry (date);
        assert (loaded != null);
        assert (loaded.content == "See https://example.com and more");
        assert (loaded.links.size == 1);
        assert (loaded.links[0].start_offset == 4);
        assert (loaded.links[0].end_offset == 23);
        assert (loaded.links[0].uri == "https://example.com");
    });

    Test.add_func ("/storage/formats-roundtrip", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-formats.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (11, 3, 2024);

        var entry = new Entry (date);
        entry.content = "Bold and italic text";
        entry.formats.add (new EntryFormat (0, 4, "bold"));
        entry.formats.add (new EntryFormat (9, 15, "italic"));

        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        var loaded = sm.get_entry (date);
        assert (loaded != null);
        assert (loaded.content == "Bold and italic text");
        assert (loaded.formats.size == 2);
        assert (loaded.formats[0].tag_name == "bold");
        assert (loaded.formats[0].start_offset == 0);
        assert (loaded.formats[0].end_offset == 4);
        assert (loaded.formats[1].tag_name == "italic");
        assert (loaded.formats[1].start_offset == 9);
        assert (loaded.formats[1].end_offset == 15);
    });
}

void add_open_and_null_db_tests () {
    Test.add_func ("/storage/open-failure", () => {
        // Use a clearly invalid path (under a non-existent directory) so opening fails.
        string invalid_dir = Path.build_filename (Environment.get_tmp_dir (), "almanah-nonexistent-dir");
        string path = Path.build_filename (invalid_dir, "db.sqlite");

        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        bool ok = sm.open (out err);
        assert (!ok);
        assert (err != null);
    });

    Test.add_func ("/storage/null-db-behaviour", () => {
        // Exercise branches that are taken when the database has not been opened.
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-null.sqlite");
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        // get_month_marked_days should return an array of the right size, all false.
        int year = 2024;
        int month = 1;
        bool[] days = sm.get_month_marked_days (year, month);
        assert (days.length == Date.get_days_in_month ((DateMonth) month, (DateYear) year));
        foreach (var marked in days) {
            assert (!marked);
        }

        // entry_exists and get_entry should behave gracefully with a null db.
        Date date = Date ();
        date.set_dmy (1, 1, 2024);
        assert (!sm.entry_exists (date));
        assert (sm.get_entry (date) == null);

        // get_entry_tags and get_all_tags should return empty collections.
        var tags = sm.get_entry_tags (date);
        assert (tags.length == 0);
        var all_tags = sm.get_all_tags ();
        assert (all_tags.length == 0);

        // search_entries with a non-empty query and a null db should return no results.
        var results = sm.search_entries ("anything");
        assert (results.size == 0);

        // set_entry and tag helpers should throw when the database is not connected.
        var entry = new Entry (date);
        entry.content = "Should fail";

        bool threw = false;
        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            threw = true;
        }
        assert (threw);

        threw = false;
        try {
            sm.add_entry_tag (date, "tag");
        } catch (StorageError e) {
            threw = true;
        }
        assert (threw);

        threw = false;
        try {
            sm.remove_entry_tag (date, "tag");
        } catch (StorageError e) {
            threw = true;
        }
        assert (threw);
    });

    Test.add_func ("/storage/read-entries-open-error", () => {
        // read_entries_from_database should throw when the database file cannot be opened.
        string invalid_dir = Path.build_filename (Environment.get_tmp_dir (), "almanah-nonexistent-dir-2");
        string path = Path.build_filename (invalid_dir, "db.sqlite");

        bool threw = false;
        try {
            StorageManager.read_entries_from_database (path);
        } catch (StorageError e) {
            threw = true;
        }
        assert (threw);
    });
}

void add_month_marked_days_tests () {
    Test.add_func ("/storage/month-marked-days", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-month.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date d1 = Date ();
        d1.set_dmy (5, 1, 2024);
        var e1 = new Entry (d1);
        e1.content = "First";
        try {
            sm.set_entry (e1);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        Date d2 = Date ();
        d2.set_dmy (10, 1, 2024);
        var e2 = new Entry (d2);
        e2.content = "Second";
        try {
            sm.set_entry (e2);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        bool[] days = sm.get_month_marked_days (2024, 1);
        assert (days.length == Date.get_days_in_month ((DateMonth) 1, (DateYear) 2024));
        assert (days[4]);  // 5th
        assert (days[9]);  // 10th
        assert (!days[0]); // 1st
    });

    Test.add_func ("/storage/month-marked-days-empty", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-month-empty.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        // No entries for February 2024.
        bool[] days = sm.get_month_marked_days (2024, 2);
        assert (days.length == Date.get_days_in_month ((DateMonth) 2, (DateYear) 2024));
        foreach (var marked in days) {
            assert (!marked);
        }
    });
}

void add_tag_tests () {
    Test.add_func ("/storage/tags-basic", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-tags.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (3, 1, 2024);
        var entry = new Entry (date);
        entry.content = "Tagged entry";
        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        try {
            sm.add_entry_tag (date, "work");
            sm.add_entry_tag (date, "personal");
        } catch (StorageError e) {
            assert_not_reached ();
        }

        var tags = sm.get_entry_tags (date);
        assert (tags.length == 2);
        // Tags are ordered alphabetically.
        assert (tags[0] == "personal");
        assert (tags[1] == "work");

        // get_all_tags should return the same unique, ordered list.
        var all_tags = sm.get_all_tags ();
        assert (all_tags.length == 2);
        assert (all_tags[0] == "personal");
        assert (all_tags[1] == "work");

        // Removing a tag should update results.
        try {
            sm.remove_entry_tag (date, "work");
        } catch (StorageError e) {
            assert_not_reached ();
        }

        var tags_after = sm.get_entry_tags (date);
        assert (tags_after.length == 1);
        assert (tags_after[0] == "personal");
    });

    Test.add_func ("/storage/tags-remove-nonexistent", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-tags-remove.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (7, 1, 2024);
        var entry = new Entry (date);
        entry.content = "One tag only";
        try {
            sm.set_entry (entry);
            sm.add_entry_tag (date, "only");
        } catch (StorageError e) {
            assert_not_reached ();
        }

        // Removing a tag that is not on this entry should not throw.
        try {
            sm.remove_entry_tag (date, "nonexistent");
        } catch (StorageError e) {
            assert_not_reached ();
        }
        var tags = sm.get_entry_tags (date);
        assert (tags.length == 1);
        assert (tags[0] == "only");
    });
}

void add_listing_and_search_tests () {
    Test.add_func ("/storage/list-all-entries-empty", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-list-empty.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        var all = sm.get_all_entries ();
        assert (all.size == 0);
    });

    Test.add_func ("/storage/list-all-entries", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-list.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date older = Date ();
        older.set_dmy (1, 1, 2024);
        var e_old = new Entry (older);
        e_old.content = "Older entry";

        Date newer = Date ();
        newer.set_dmy (2, 1, 2025);
        var e_new = new Entry (newer);
        e_new.content = "Newer entry";
        e_new.important = true;

        try {
            sm.set_entry (e_old);
            sm.set_entry (e_new);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        var all = sm.get_all_entries ();
        assert (all.size == 2);
        // Newer entry should come first (descending order).
        assert (all[0].date.get_year () == 2025);
        assert (all[0].date.get_day () == 2);
        assert (all[0].important);
        assert (all[1].date.get_year () == 2024);
    });

    Test.add_func ("/storage/search-entries", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-search.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date d1 = Date ();
        d1.set_dmy (1, 2, 2024);
        var e1 = new Entry (d1);
        e1.content = "Went running today";

        Date d2 = Date ();
        d2.set_dmy (2, 2, 2024);
        var e2 = new Entry (d2);
        e2.content = "Just another day";

        try {
            sm.set_entry (e1);
            sm.set_entry (e2);
            sm.add_entry_tag (d2, "holiday");
        } catch (StorageError e) {
            assert_not_reached ();
        }

        // Empty or whitespace-only search should return nothing.
        var empty_results = sm.search_entries ("   ");
        assert (empty_results.size == 0);

        // Search by content.
        var by_content = sm.search_entries ("running");
        assert (by_content.size == 1);
        assert (by_content[0].date.get_day () == 1);

        // Search by tag.
        var by_tag = sm.search_entries ("holiday");
        assert (by_tag.size == 1);
        assert (by_tag[0].date.get_day () == 2);
    });

    Test.add_func ("/storage/search-entries-multiple-matches", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-search-multi.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date d1 = Date ();
        d1.set_dmy (1, 3, 2024);
        var e1 = new Entry (d1);
        e1.content = "Coffee with Alice";

        Date d2 = Date ();
        d2.set_dmy (2, 3, 2024);
        var e2 = new Entry (d2);
        e2.content = "Meeting with Bob";

        Date d3 = Date ();
        d3.set_dmy (3, 3, 2024);
        var e3 = new Entry (d3);
        e3.content = "Alice called again";

        try {
            sm.set_entry (e1);
            sm.set_entry (e2);
            sm.set_entry (e3);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        var alice_results = sm.search_entries ("Alice");
        assert (alice_results.size == 2);
        assert (alice_results[0].date.get_day () == 3);
        assert (alice_results[1].date.get_day () == 1);
    });

    Test.add_func ("/storage/read-entries-from-database", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-read.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (15, 3, 2024);
        var entry = new Entry (date);
        entry.content = "Read-back entry";
        entry.important = true;

        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        // Close the manager to ensure the static helper reopens the database.
        sm.close ();

        Gee.ArrayList<Entry> read_entries;
        try {
            read_entries = StorageManager.read_entries_from_database (path);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        assert (read_entries.size == 1);
        var loaded = read_entries[0];
        assert (loaded.date.get_day () == 15);
        assert (loaded.date.get_month () == 3);
        assert (loaded.content == "Read-back entry");
        assert (loaded.important);
    });

    Test.add_func ("/storage/read-entries-encrypted-no-key", () => {
        string path = Path.build_filename (Environment.get_tmp_dir (), "almanah-test-db-read-encrypted.sqlite");
        if (FileUtils.test (path, FileTest.EXISTS)) {
            FileUtils.remove (path);
        }

        // Create a normal database with one plaintext entry first.
        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (1, 5, 2024);
        var entry = new Entry (date);
        entry.content = "Plain before encryption marker";

        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        sm.close ();

        // Manually rewrite the content column to look like an encrypted payload.
        Database? db = null;
        int ec = Database.open (path, out db);
        assert (ec == Sqlite.OK && db != null);

        // This string mimics StorageManager.ENCRYPTED_PREFIX usage.
        string encrypted_like = "ENC1:fake-armored-ciphertext";
        string sql = "UPDATE entries SET content = '%s' WHERE year = 2024 AND month = 5 AND day = 1"
            .printf (encrypted_like.replace ("'", "''"));
        string? errmsg = null;
        ec = db.exec (sql, null, out errmsg);
        assert (ec == Sqlite.OK);
        db = null;

        // Now read via the helper; since no encryption key is set, we should
        // get the placeholder rather than the raw ciphertext.
        Gee.ArrayList<Entry> read_entries;
        try {
            read_entries = StorageManager.read_entries_from_database (path);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        assert (read_entries.size == 1);
        var loaded = read_entries[0];
        assert (loaded.date.get_year () == 2024);
        assert (loaded.date.get_month () == 5);
        assert (loaded.date.get_day () == 1);
        assert (loaded.content == _ ("[Encrypted entry – no decryption key selected]"));
    });
}

public static int main (string[] args) {
    // Use in-memory GSettings backend to avoid dconf writes in test environments.
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);

    Test.init (ref args);

    add_entry_model_tests ();
    add_entry_roundtrip_tests ();
    add_open_and_null_db_tests ();
    add_month_marked_days_tests ();
    add_tag_tests ();
    add_listing_and_search_tests ();

    return Test.run ();
}

