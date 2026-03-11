// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using Pango;

namespace Almanah {

public class HyperlinkTag : Gtk.TextTag {
    public string uri { get; construct; }

    public HyperlinkTag (string uri) {
        Object (uri: uri);
    }

    construct {
        foreground = "blue";
        underline = Pango.Underline.SINGLE;
    }
}

}
