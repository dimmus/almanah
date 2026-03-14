// SPDX-License-Identifier: GPL-3.0-or-later

using GLib;
using Almanah;

void add_evolution_events_tests () {
    Test.add_func ("/evolution-events/default-state", () => {
        var provider = new EvolutionEventsProvider ();

        // By default the provider should be available==false until fully wired.
        assert (!provider.available);

        Date today = Date ();
        today.set_time_t ((time_t) (new DateTime.now_local ()).to_unix ());

        var events = provider.get_past_events (today, 7);
        assert (events != null);
        assert (events.size == 0);
    });
}

public static int main (string[] args) {
    Test.init (ref args);

    add_evolution_events_tests ();

    return Test.run ();
}

