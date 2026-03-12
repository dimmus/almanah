// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Gee;

namespace Almanah {

public class Entry : Object {
    public Date date { get; construct; }
    public string content { get; set; default = ""; }
    public bool important { get; set; default = false; }

    public Date last_edited { get; set; }
    public ArrayList<EntryLink> links { get; set; default = new ArrayList<EntryLink> (); }

    public Entry (Date date) {
        Object (date: date);
        last_edited = date;
    }
}

public class EntryLink : Object {
    public int start_offset { get; set; }
    public int end_offset { get; set; }
    public string uri { get; set; }

    public EntryLink (int start_offset, int end_offset, string uri) {
        Object (start_offset: start_offset, end_offset: end_offset, uri: uri);
    }
}

}
