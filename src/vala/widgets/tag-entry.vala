// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using GLib;

namespace Almanah {

public class TagEntry : Gtk.Entry {
    public StorageManager? storage_manager { get; set; }

    public TagEntry () {
        placeholder_text = _("add tag");
        tooltip_text = _("Write the tag and press enter to save it");
    }
}

}
