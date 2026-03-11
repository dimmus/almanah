// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;

namespace Almanah {

public class EvolutionEventsProvider : Object {
    public bool available { get; private set; default = false; }

    public EvolutionEventsProvider () {
        /* Placeholder: real Evolution Data Server wiring to be added.
         * For now, we expose the structure so the UI can call into it
         * without failing even when libecal/libedataserver are absent
         * or not yet fully integrated.
         */
    }

    public Gee.ArrayList<string> get_past_events (Date around, int days_radius) {
        /* TODO: Query Evolution Data Server for events/tasks around @around
         * using libecal-2.0 and libedataserver-1.2, then return human‑readable
         * summaries to display in the Past events list.
         */
        return new Gee.ArrayList<string> ();
    }
}

}

