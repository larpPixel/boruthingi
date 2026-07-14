namespace Danbooru {
    /**
     * Shared chrome bar for search, selection, and detail headers.
     *
     * Layout: [ start ……………… expands ……………… ]  gap  [ end ]
     */
    public class AppBar : Gtk.Box {
        private Gtk.Box start_box;
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
            add_css_class(is_bottom ? "bottom" : "top");

            hexpand = true;
            valign = Gtk.Align.FILL;

            start_box = make_slot();
            start_box.hexpand = true;

            end_box = make_slot();
            end_box.halign = Gtk.Align.END;
            // Keeps search button from sitting flush against filter controls.
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

        public void pack_end(Gtk.Widget child) {
            end_box.append(child);
        }

        public static Gtk.Separator make_separator() {
            var sep = new Gtk.Separator(Gtk.Orientation.VERTICAL);
            sep.add_css_class("app-bar-sep");
            sep.valign = Gtk.Align.CENTER;
            return sep;
        }
    }
}
