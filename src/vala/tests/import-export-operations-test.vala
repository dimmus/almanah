// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Almanah;

void add_import_export_tests () {
    Test.add_func ("/import-export/import-text-new-entry", () => {
        string db_path = Path.build_filename (Environment.get_tmp_dir (), "almanah-import-text-new-db.sqlite");
        if (FileUtils.test (db_path, FileTest.EXISTS)) {
            FileUtils.remove (db_path);
        }

        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (db_path, settings);

        Error? err = null;
        assert (sm.open (out err));

        // Prepare a temporary folder with a single date-named file.
        string tmpdir = DirUtils.mkdtemp (Path.build_filename (Environment.get_tmp_dir (), "almanah-import-text-XXXXXX"));
        var folder = File.new_for_path (tmpdir);

        string filename = "2024-01-05";
        string file_path = Path.build_filename (tmpdir, filename);
        try {
            FileUtils.set_contents (file_path, "Imported content");
        } catch (Error e) {
            assert_not_reached ();
        }

        var ops = new ImportExportOperations (sm);

        bool finished_ok = false;
        string? finished_msg = null;
        var loop = new MainLoop ();

        ops.finished.connect ((success, msg) => {
            finished_ok = success;
            finished_msg = msg;
            loop.quit ();
        });

        ops.import_text_files_async (folder);
        loop.run ();

        assert (finished_ok);
        assert (finished_msg == null || finished_msg.strip () == "");

        Date date = Date ();
        date.set_dmy (5, 1, 2024);
        var entry = sm.get_entry (date);
        assert (entry != null);
        assert (entry.content == "Imported content");
    });

    Test.add_func ("/import-export/import-text-merge-existing", () => {
        string db_path = Path.build_filename (Environment.get_tmp_dir (), "almanah-import-text-merge-db.sqlite");
        if (FileUtils.test (db_path, FileTest.EXISTS)) {
            FileUtils.remove (db_path);
        }

        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (db_path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (10, 2, 2024);

        var existing = new Entry (date);
        existing.content = "Existing entry content";
        existing.important = true;
        try {
            sm.set_entry (existing);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        // Prepare imported content for the same date in a temporary folder.
        string tmpdir = DirUtils.mkdtemp (Path.build_filename (Environment.get_tmp_dir (), "almanah-import-text-merge-XXXXXX"));
        var folder = File.new_for_path (tmpdir);

        string filename = "2024-02-10";
        string file_path = Path.build_filename (tmpdir, filename);
        try {
            FileUtils.set_contents (file_path, "Imported other content");
        } catch (Error e) {
            assert_not_reached ();
        }

        var ops = new ImportExportOperations (sm);

        bool finished_ok = false;
        string? finished_msg = null;
        var loop = new MainLoop ();

        ops.finished.connect ((success, msg) => {
            finished_ok = success;
            finished_msg = msg;
            loop.quit ();
        });

        ops.import_text_files_async (folder);
        loop.run ();

        assert (finished_ok);
        assert (finished_msg == null || finished_msg.strip () == "");

        var merged = sm.get_entry (date);
        assert (merged != null);

        // Merged content should contain both original and imported pieces and a header.
        assert (merged.content.index_of ("Existing entry content") >= 0);
        assert (merged.content.index_of ("Imported other content") >= 0);
        assert (merged.content.index_of ("Entry imported from") >= 0);

        // Important flag should be preserved (existing was important).
        assert (merged.important);
    });

    Test.add_func ("/import-export/import-text-invalid-folder", () => {
        // A File without a filesystem path should trigger FILE_NOT_FOUND.
        var bogus_folder = File.new_for_uri ("resource://invalid-folder");

        string db_path = Path.build_filename (Environment.get_tmp_dir (), "almanah-import-text-invalid-folder.sqlite");
        if (FileUtils.test (db_path, FileTest.EXISTS)) {
            FileUtils.remove (db_path);
        }

        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (db_path, settings);

        Error? err = null;
        assert (sm.open (out err));

        var ops = new ImportExportOperations (sm);

        bool finished_ok = false;
        string? finished_msg = null;
        var loop = new MainLoop ();

        ops.finished.connect ((success, msg) => {
            finished_ok = success;
            finished_msg = msg;
            loop.quit ();
        });

        ops.import_text_files_async (bogus_folder);
        loop.run ();

        assert (!finished_ok);
        assert (finished_msg != null);
        assert (finished_msg.index_of ("Invalid folder path") >= 0);
    });

    Test.add_func ("/import-export/import-database-invalid-file", () => {
        // A File without a filesystem path should trigger FILE_NOT_FOUND.
        var bogus_file = File.new_for_uri ("resource://invalid-db");

        string db_path = Path.build_filename (Environment.get_tmp_dir (), "almanah-import-db-invalid.sqlite");
        if (FileUtils.test (db_path, FileTest.EXISTS)) {
            FileUtils.remove (db_path);
        }

        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (db_path, settings);

        Error? err = null;
        assert (sm.open (out err));

        var ops = new ImportExportOperations (sm);

        bool finished_ok = false;
        string? finished_msg = null;
        var loop = new MainLoop ();

        ops.finished.connect ((success, msg) => {
            finished_ok = success;
            finished_msg = msg;
            loop.quit ();
        });

        ops.import_database_async (bogus_file);
        loop.run ();

        assert (!finished_ok);
        assert (finished_msg != null);
        assert (finished_msg.index_of ("Invalid file path") >= 0);
    });

    Test.add_func ("/import-export/export-database", () => {
        string db_path = Path.build_filename (Environment.get_tmp_dir (), "almanah-export-db.sqlite");
        if (FileUtils.test (db_path, FileTest.EXISTS)) {
            FileUtils.remove (db_path);
        }

        var settings = new Settings ("io.github.dimmus.almanah");
        var sm = new StorageManager (db_path, settings);

        Error? err = null;
        assert (sm.open (out err));

        Date date = Date ();
        date.set_dmy (15, 4, 2024);
        var entry = new Entry (date);
        entry.content = "Database export entry";

        try {
            sm.set_entry (entry);
        } catch (StorageError e) {
            assert_not_reached ();
        }

        string tmpdir = DirUtils.mkdtemp (Path.build_filename (Environment.get_tmp_dir (), "almanah-export-db-XXXXXX"));
        string dest_path = Path.build_filename (tmpdir, "exported.sqlite");
        var dest_file = File.new_for_path (dest_path);

        var ops = new ImportExportOperations (sm);

        bool finished_ok = false;
        string? finished_msg = null;
        var loop = new MainLoop ();

        ops.finished.connect ((success, msg) => {
            finished_ok = success;
            finished_msg = msg;
            loop.quit ();
        });

        ops.export_database_async (dest_file);
        loop.run ();

        assert (finished_ok);
        assert (finished_msg == null || finished_msg.strip () == "");
        assert (FileUtils.test (dest_path, FileTest.EXISTS));

        // Open the exported database and ensure the entry is present.
        var sm2 = new StorageManager (dest_path, settings);
        Error? err2 = null;
        assert (sm2.open (out err2));

        var exported_entry = sm2.get_entry (date);
        assert (exported_entry != null);
        assert (exported_entry.content == "Database export entry");
    });
}

public static int main (string[] args) {
    // Use in-memory GSettings backend to avoid dconf writes in test environments.
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);

    Test.init (ref args);

    add_import_export_tests ();

    return Test.run ();
}

