namespace Danbooru {
    public class Application : Adw.Application {
        private bool css_applied = false;

        public Application() {
            Object(
                application_id: Config.APP_ID,
                flags: GLib.ApplicationFlags.FLAGS_NONE
            );
        }

        private void setup_css() {
            if (css_applied) return;
            css_applied = true;
            var css_provider = new Gtk.CssProvider();
            var css = """
                /* === Thumbnail grid === */
                .thumbnail-card {
                    background: @card_bg_color;
                    border: 1px solid alpha(@window_fg_color, 0.08);
                    transition: all 120ms ease;
                }
                .thumbnail-card:hover {
                    border-color: alpha(@accent_bg_color, 0.3);
                    background: alpha(@accent_bg_color, 0.02);
                }
                .thumbnail-card.selected {
                    border: 2px solid @accent_bg_color;
                    background: alpha(@accent_bg_color, 0.08);
                    margin: -1px;
                }
                .thumbnail-image {
                    border-radius: 8px 8px 0 0;
                    background: @view_bg_color;
                }

                /* === Badges === */
                .badge {
                    padding: 1px 6px;
                    border-radius: 4px;
                    font-size: 0.75em;
                    font-weight: 600;
                    letter-spacing: 0.3px;
                    color: white;
                }
                .badge.s {
                    background: shade(@success_bg_color, 0.85);
                }
                .badge.q {
                    background: #b8860b;
                }
                .badge.e {
                    background: #b22222;
                }

                /* === Info pills on thumbnails === */
                .info-pill {
                    padding: 1px 6px;
                    border-radius: 4px;
                    font-size: 0.7em;
                    font-weight: 600;
                    font-family: monospace;
                    background: rgba(0, 0, 0, 0.55);
                    color: white;
                }

                /* === Metadata labels === */
                .page-label {
                    font-size: 0.85em;
                    font-family: monospace;
                    padding: 0 12px;
                    font-weight: 600;
                }

                /* === Detail view === */
                .detail-header-box {
                    background: @headerbar_bg_color;
                    border-bottom: 1px solid @borders;
                }
                .detail-id, .heading {
                    font-weight: 700;
                    font-size: 1.1em;
                }
                .meta-label {
                    font-size: 0.8em;
                    font-weight: 600;
                    font-family: monospace;
                    opacity: 0.6;
                }
                .meta-value {
                    font-size: 0.85em;
                    font-family: monospace;
                }
                .image-frame {
                    border-radius: 8px;
                    border: 1px solid alpha(@window_fg_color, 0.1);
                }
                .detail-image {
                    border-radius: 8px;
                }

                /* === Tag buttons === */
                .tag-button {
                    padding: 2px 10px;
                    font-size: 0.8em;
                    font-family: monospace;
                    border-radius: 8px;
                    background: alpha(@accent_bg_color, 0.12);
                    border: none;
                }
                .tag-button:hover {
                    background: alpha(@accent_bg_color, 0.25);
                }
                .tag-button.artist {
                    background: alpha(@warning_bg_color, 0.15);
                }
                .tag-button.artist:hover {
                    background: alpha(@warning_bg_color, 0.3);
                }
                .tag-button.character {
                    background: alpha(@success_bg_color, 0.15);
                }
                .tag-button.character:hover {
                    background: alpha(@success_bg_color, 0.3);
                }
                .tag-button.copyright {
                    background: alpha(@error_bg_color, 0.12);
                }
                .tag-button.copyright:hover {
                    background: alpha(@error_bg_color, 0.25);
                }
                .tag-button.meta {
                    background: alpha(@accent_bg_color, 0.06);
                }
                .tag-button.meta:hover {
                    background: alpha(@accent_bg_color, 0.15);
                }
                .tag-section-label {
                    font-size: 0.75em;
                    font-weight: 600;
                    font-family: monospace;
                    opacity: 0.5;
                    min-width: 80px;
                }

                /* === Selection === */
                .selection-overlay {
                    background: rgba(0, 0, 0, 0.45);
                    border-radius: 6px;
                }

                /* === Autocomplete === */
                .suggestion-name {
                    font-size: 0.85em;
                    font-family: monospace;
                }
                .suggestion-count {
                    font-size: 0.75em;
                    font-family: monospace;
                    opacity: 0.5;
                }
                .suggestion-cat {
                    font-size: 0.7em;
                    font-family: monospace;
                    font-weight: 600;
                }

                /* === Toolbar controls === */
                .toolbar-search {
                    background: alpha(currentColor, 0.04);
                    border-radius: 8px;
                    padding: 4px;
                }

                /* === Download dialog === */
                .download-file-row {
                    padding: 6px 0;
                    border-bottom: 1px solid alpha(@borders, 0.3);
                }
                .download-file-row:last-child {
                    border-bottom: none;
                }
                .download-status-icon {
                    opacity: 0.7;
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
            setup_css();

            var window = new MainWindow(this);
            window.present();
        }
    }
}
