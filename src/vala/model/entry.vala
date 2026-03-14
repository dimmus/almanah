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
    public ArrayList<EntryFormat> formats { get; set; default = new ArrayList<EntryFormat> (); }

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

/** Format tag applied to a range: "bold", "italic", or "underline". */
public class EntryFormat : Object {
    public int start_offset { get; set; }
    public int end_offset { get; set; }
    public string tag_name { get; set; }

    public EntryFormat (int start_offset, int end_offset, string tag_name) {
        Object (start_offset: start_offset, end_offset: end_offset, tag_name: tag_name);
    }
}

}
