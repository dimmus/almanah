// SPDX-License-Identifier: GPL-3.0-or-later

using Gtk;
using GLib;

namespace Almanah {

private enum UserEvent {
    NONE = 1,
    FIRST,
    TODAY,
    DAY,
    MONTH
}

[GtkTemplate (ui = "/org/gnome/Almanah/ui/calendar-button.ui")]
public class CalendarButton : Gtk.Button {
    [GtkChild] unowned Gtk.Popover dock;
    [GtkChild] unowned Gtk.Calendar calendar;
    [GtkChild] unowned Gtk.Button today_button;
    [GtkChild] unowned Gtk.Button select_date_button;

    private UserEvent user_event = UserEvent.FIRST;
    private StorageManager? _storage_manager;

    public StorageManager? storage_manager {
        get { return _storage_manager; }
        set {
            _storage_manager = value;
            update_calendar_marks ();
        }
    }

    public signal void day_selected ();
    public signal void select_date_clicked ();

    construct {
        child = new Gtk.Image.from_icon_name ("x-office-calendar-symbolic");
        add_css_class ("image-button");
        dock.set_parent (this);
        today_button.add_css_class ("flat");
        select_date_button.add_css_class ("flat");

        var today_gesture = new Gtk.GestureClick ();
        today_button.add_controller (today_gesture);
        today_gesture.pressed.connect (() => { user_event = UserEvent.TODAY; });

        var select_gesture = new Gtk.GestureClick ();
        select_date_button.add_controller (select_gesture);
        select_gesture.pressed.connect (() => { user_event = UserEvent.NONE; });

        calendar.notify.connect ((obj, pspec) => {
            if (pspec.name == "date")
                update_calendar_marks ();
        });
    }

    ~CalendarButton () {
        if (dock.get_parent () == this) {
            dock.unparent ();
        }
    }

    public override void dispose () {
        if (dock.get_parent () == this) {
            dock.unparent ();
        }
        base.dispose ();
    }

    [GtkCallback]
    void dock_closed () {
        user_event = UserEvent.NONE;
    }

    [GtkCallback]
    void button_clicked_cb () {
        dock.popup ();
    }

    [GtkCallback]
    void day_selected_cb () {
        if (user_event < UserEvent.DAY) {
            user_event = UserEvent.DAY;
            dock.popdown ();
        }
        user_event = UserEvent.NONE;
        day_selected ();
    }

    [GtkCallback]
    void month_changed_cb () {
        if (user_event != UserEvent.TODAY) {
            user_event = UserEvent.MONTH;
        }
    }

    [GtkCallback]
    void today_clicked_cb () {
        select_today ();
    }

    [GtkCallback]
    void select_date_clicked_cb () {
        select_date_clicked ();
    }

    void update_calendar_marks () {
        if (_storage_manager == null) {
            calendar.clear_marks ();
            return;
        }

        var dt = calendar.get_date ();
        if (dt == null) {
            calendar.clear_marks ();
            return;
        }

        int year = dt.get_year ();
        int month = dt.get_month ();
        var days = _storage_manager.get_month_marked_days (year, month);

        calendar.clear_marks ();
        for (var i = 0; i < days.length; i++) {
            if (days[i]) {
                calendar.mark_day ((uint) (i + 1));
            }
        }
    }

    public void select_date (Date date) {
        var dt = new DateTime.local (
            date.get_year (),
            date.get_month (),
            date.get_day (),
            0, 0, 0
        );
        calendar.select_day (dt);
    }

    public void select_today () {
        var now = new DateTime.now_local ();
        calendar.select_day (now);
    }

    public Date get_date () {
        var dt = calendar.get_date ();
        var result = Date ();
        if (dt != null) {
            result.set_dmy (
                (DateDay) dt.get_day_of_month (),
                (DateMonth) dt.get_month (),
                (DateYear) dt.get_year ()
            );
        }
        return result;
    }

    public void popdown () {
        dock.popdown ();
    }
}

}
