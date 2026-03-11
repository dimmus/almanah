// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Almanah;

void add_entry_tests () {
    Test.add_func ("/entry/defaults-and-mutability", () => {
        Date d = Date ();
        d.set_dmy (12, 8, 2024);

        var e = new Entry (d);

        // Constructor should copy the date and set last_edited.
        assert (e.date.get_day () == 12);
        assert (e.date.get_month () == 8);
        assert (e.date.get_year () == 2024);

        assert (e.last_edited.valid ());
        assert (e.last_edited.get_day () == 12);
        assert (e.last_edited.get_month () == 8);
        assert (e.last_edited.get_year () == 2024);

        // Defaults.
        assert (e.content == "");
        assert (!e.important);

        // Mutability of properties.
        e.content = "Updated content";
        e.important = true;

        Date later = Date ();
        later.set_dmy (13, 8, 2024);
        e.last_edited = later;

        assert (e.content == "Updated content");
        assert (e.important);
        assert (e.last_edited.get_day () == 13);
        assert (e.last_edited.get_month () == 8);
        assert (e.last_edited.get_year () == 2024);
    });

    Test.add_func ("/entry/independent-instances", () => {
        Date d1 = Date ();
        d1.set_dmy (1, 1, 2024);
        Date d2 = Date ();
        d2.set_dmy (2, 1, 2024);

        var e1 = new Entry (d1);
        var e2 = new Entry (d2);

        e1.content = "First";
        e2.content = "Second";
        e1.important = true;
        e2.important = false;

        assert (e1.date.get_day () == 1);
        assert (e2.date.get_day () == 2);
        assert (e1.content == "First");
        assert (e2.content == "Second");
        assert (e1.important);
        assert (!e2.important);
    });

    Test.add_func ("/entry/date-argument-is-copied", () => {
        Date original = Date ();
        original.set_dmy (5, 5, 2024);

        var e = new Entry (original);

        // Mutate the original Date afterwards; the entry's date should not change.
        original.set_dmy (6, 6, 2024);

        assert (e.date.get_day () == 5);
        assert (e.date.get_month () == 5);
        assert (e.date.get_year () == 2024);

        // last_edited should still reflect the constructor date.
        assert (e.last_edited.get_day () == 5);
        assert (e.last_edited.get_month () == 5);
        assert (e.last_edited.get_year () == 2024);
    });
}

public static int main (string[] args) {
    Test.init (ref args);

    add_entry_tests ();

    int result = Test.run ();
    stdout.printf ("# entry tests: 3\n");
    return result;
}

