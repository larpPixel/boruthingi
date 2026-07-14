namespace Danbooru {
    /**
     * Shared chrome bar for search, selection, and detail headers.
     *
     * Layout:  [ start ……………… expands ……………… ]  gap  [ end ]
     *
     * The gap is intentional: the expanding region is the *start group*,
     * so a trailing start control (e.g. search button) does not sit flush
     * against the first end control (e.g. Medium dropdown).
     */
    public class AppBar : Gtk.Box {
        private Gtk.Box start_box;
        private Gtk.Box? center_box = null;
        private Gtk.Box end_box;

        public bool is_bottom { get; construct; default = false; }

        public AppBar(bool bottom = false) {
            Object(
                orientation: Gtk.Orientation.HORIZONTAL,
                spacing: 0,
                is_bottom: bottom
            );
        }

        construct {
            add_css_class("app-bar");
            if (is_bottom) {
                add_css_class("bottom");
            } else {
                add_css_class("top");
            }

            hexpand = true;
            valign = Gtk.Align.FILL;

            start_box = make_slot();
            start_box.hexpand = true;
            start_box.halign = Gtk.Align.FILL;

            end_box = make_slot();
            end_box.halign = Gtk.Align.END;
            // Separates primary actions (search) from secondary (filters / download).
            end_box.margin_start = 20;

            append(start_box);
            append(end_box);
        }

        private static Gtk.Box make_slot() {
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            box.valign = Gtk.Align.CENTER;
            return box;
        }

        public void pack_start(Gtk.Widget child) {
            start_box.append(child);
        }

        public void pack_center(Gtk.Widget child) {
            if (center_box == null) {
                center_box = make_slot();
                center_box.halign = Gtk.Align.CENTER;
                // Insert between start and end.
                insert_child_after(center_box, start_box);
            }
            center_box.append(child);
        }

        public void pack_end(Gtk.Widget child) {
            end_box.append(child);
        }

        /** Vertical separator matching app-bar chrome. */
        public static Gtk.Separator make_separator() {
            var sep = new Gtk.Separator(Gtk.Orientation.VERTICAL);
            sep.add_css_class("app-bar-sep");
            sep.valign = Gtk.Align.CENTER;
            return sep;
        }
    }
}
