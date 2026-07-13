namespace Danbooru {
    public class Application : Gtk.Application {
        public Application() {
            Object(
                application_id: Config.APP_ID,
                flags: GLib.ApplicationFlags.FLAGS_NONE
            );
        }

        construct {
            setup_css();
        }

        private void setup_css() {
            var css_provider = new Gtk.CssProvider();
            var css = """
                .thumbnail-card {
                    background: @card_bg_color;
                    border-radius: 6px;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.2);
                    transition: all 150ms ease;
                }
                .thumbnail-card:hover {
                    box-shadow: 0 2px 6px rgba(0,0,0,0.3);
                }
                .thumbnail-card.selected {
                    border: 2px solid @accent_bg_color;
                    background: alpha(@accent_bg_color, 0.1);
                }
                .thumbnail-image {
                    border-radius: 6px 6px 0 0;
                }
                .badge {
                    padding: 1px 6px;
                    border-radius: 10px;
                    font-size: 0.8em;
                    font-weight: bold;
                    color: white;
                }
                .badge.safe {
                    background: #3584e4;
                }
                .badge.questionable {
                    background: #e8a400;
                }
                .badge.explicit {
                    background: #e53434;
                }
                .score-label {
                    font-size: 0.85em;
                    font-weight: bold;
                    color: @theme_fg_color;
                }
                .dims-label {
                    font-size: 0.75em;
                    color: @insensitive_fg_color;
                }
                .selection-check {
                    background: rgba(0,0,0,0.4);
                    border-radius: 12px;
                }
                .heading {
                    font-size: 1.1em;
                    font-weight: bold;
                }
                .meta-label {
                    font-weight: bold;
                    font-size: 0.9em;
                }
                .meta-value {
                    font-size: 0.9em;
                }
                .image-frame {
                    border-radius: 8px;
                }
                .tag-button {
                    padding: 2px 8px;
                    font-size: 0.8em;
                    border-radius: 12px;
                    background: alpha(@accent_bg_color, 0.15);
                    color: @accent_fg_color;
                    border: none;
                }
                .tag-button:hover {
                    background: alpha(@accent_bg_color, 0.3);
                }
                .tag-section-label {
                    font-weight: bold;
                    font-size: 0.85em;
                    color: @insensitive_fg_color;
                    min-width: 80px;
                }
                .pill {
                    border-radius: 16px;
                    padding: 4px 12px;
                }
                .search-bar {
                    min-width: 300px;
                }
                .pagination-label {
                    font-size: 0.9em;
                    padding: 0 8px;
                }
                .empty-state {
                    font-size: 1.2em;
                    color: @insensitive_fg_color;
                    padding: 40px;
                }
                .tag-suggestion {
                    padding: 4px 8px;
                }
                .tag-suggestion:hover {
                    background: alpha(@accent_bg_color, 0.1);
                }
            """;
            try {
                css_provider.load_from_string(css);
                var display = Gdk.Display.get_default();
                if (display != null) {
                    Gtk.StyleContext.add_provider_for_display(
                        display, css_provider,
                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                    );
                }
            } catch (Error e) {
                warning("CSS error: %s", e.message);
            }
        }

        protected override void activate() {
            var window = new MainWindow(this);
            window.present();
        }
    }
}
