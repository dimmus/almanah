// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;

namespace Almanah {

public class Entry : Object {
    public Date date { get; construct; }
    public string content { get; set; default = ""; }
    public bool important { get; set; default = false; }

    public Date last_edited { get; set; }

    public Entry (Date date) {
        Object (date: date);
        last_edited = date;
    }
}

}
