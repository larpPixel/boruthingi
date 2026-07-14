namespace Danbooru {
    public class Application : Adw.Application {
        private bool css_applied = false;

        public Application() {
            Object(
                application_id: Config.APP_ID,
                flags: GLib.ApplicationFlags.FLAGS_NONE
            );

            var style_manager = Adw.StyleManager.get_default();
            style_manager.color_scheme = Adw.ColorScheme.PREFER_DARK;
        }

        private void setup_css() {
            if (css_applied) return;
            css_applied = true;
            var css_provider = new Gtk.CssProvider();
            var css = """
                /* === Base: dark, dense, terminal-adjacent === */
                window {
                    background: #141414;
                    color: #d0d0d0;
                }

                /* === App toolbars (main search bar + detail header) === */
                .app-toolbar {
                    background: #1a1a1a;
                    border-bottom: 1px solid #2a2a2a;
                    border-radius: 0;
                    padding: 6px 12px;
                }

                /* === Inputs === */
                entry,
                spinbutton,
                dropdown {
                    background: #222222;
                    color: #d0d0d0;
                    border: 1px solid #333333;
                    border-radius: 2px;
                    font-family: monospace;
                    font-size: 0.85em;
                    min-height: 28px;
                }
                entry:focus,
                spinbutton:focus,
                dropdown:focus {
                    border-color: #b8860b;
                    outline-color: alpha(#b8860b, 0.4);
                }
                entry selection {
                    background: alpha(#b8860b, 0.35);
                }

                /* === Buttons === */
                button {
                    background: #222222;
                    color: #d0d0d0;
                    border: 1px solid #333333;
                    border-radius: 2px;
                    font-family: monospace;
                    font-size: 0.85em;
                    padding: 4px 10px;
                    min-height: 28px;
                }
                button:hover {
                    background: #2a2a2a;
                    border-color: #3a3a3a;
                }
                button:active {
                    background: #333333;
                }
                button.suggested-action {
                    background: #b8860b;
                    color: #111111;
                    border-color: #b8860b;
                    font-weight: 700;
                }
                button.suggested-action:hover {
                    background: #d4a017;
                    border-color: #d4a017;
                }

                /* === Switches === */
                switch {
                    background: #222222;
                    border: 1px solid #333333;
                    border-radius: 14px;
                }
                switch:checked {
                    background: #b8860b;
                    border-color: #b8860b;
                }
                switch slider {
                    background: #d0d0d0;
                    border-radius: 12px;
                }

                /* === Thumbnail grid === */
                .thumbnail-card {
                    background: #1a1a1a;
                    border: 1px solid #2a2a2a;
                    border-radius: 2px;
                    transition: border-color 80ms ease;
                }
                .thumbnail-card:hover {
                    border-color: #b8860b;
                    background: #1c1c1c;
                }
                .thumbnail-card.selected {
                    border: 1px solid #b8860b;
                    background: alpha(#b8860b, 0.08);
                }
                .thumbnail-image {
                    border-radius: 0;
                    background: #111111;
                }

                /* === Badges === */
                .badge {
                    padding: 1px 5px;
                    border-radius: 2px;
                    font-size: 0.65em;
                    font-weight: 700;
                    letter-spacing: 0.4px;
                    text-transform: uppercase;
                    color: #111111;
                    font-family: monospace;
                }
                .badge.s {
                    background: #6b8e6b;
                }
                .badge.q {
                    background: #b8860b;
                }
                .badge.e {
                    background: #a52a2a;
                }

                /* === Info pills on thumbnails === */
                .info-pill {
                    padding: 1px 5px;
                    border-radius: 2px;
                    font-size: 0.65em;
                    font-weight: 600;
                    font-family: monospace;
                    background: rgba(0, 0, 0, 0.75);
                    color: #d0d0d0;
                    letter-spacing: 0.2px;
                }

                /* === Bottom action bar === */
                actionbar {
                    background: #1a1a1a;
                    border-top: 1px solid #2a2a2a;
                    padding: 4px 12px;
                }
                actionbar button {
                    min-height: 28px;
                }

                /* === Metadata labels === */
                .page-label {
                    font-size: 0.8em;
                    font-family: monospace;
                    padding: 0 12px;
                    font-weight: 600;
                    color: #a0a0a0;
                }
                .meta-label {
                    font-size: 0.75em;
                    font-weight: 600;
                    font-family: monospace;
                    color: #808080;
                }
                .meta-value {
                    font-size: 0.8em;
                    font-family: monospace;
                    color: #d0d0d0;
                }

                /* === Detail view === */
                .detail-id, .heading {
                    font-weight: 700;
                    font-size: 1em;
                    font-family: monospace;
                    color: #d0d0d0;
                }
                .image-frame {
                    border-radius: 2px;
                    border: 1px solid #2a2a2a;
                    background: #111111;
                }
                .detail-image {
                    border-radius: 0;
                }

                /* === Tag buttons === */
                .tag-button {
                    padding: 2px 8px;
                    font-size: 0.78em;
                    font-family: monospace;
                    border-radius: 2px;
                    background: #222222;
                    border: 1px solid #333333;
                    color: #d0d0d0;
                }
                .tag-button:hover {
                    background: #2a2a2a;
                    border-color: #b8860b;
                }
                .tag-button.artist {
                    border-color: alpha(#cd853f, 0.5);
                }
                .tag-button.character {
                    border-color: alpha(#6b8e6b, 0.5);
                }
                .tag-button.copyright {
                    border-color: alpha(#a0522d, 0.4);
                }
                .tag-button.meta {
                    border-color: alpha(#808080, 0.4);
                }
                .tag-section-label {
                    font-size: 0.7em;
                    font-weight: 700;
                    font-family: monospace;
                    color: #707070;
                    text-transform: uppercase;
                    letter-spacing: 0.4px;
                    min-width: 80px;
                }

                /* === Selection === */
                .selection-overlay {
                    background: rgba(0, 0, 0, 0.55);
                    border-radius: 2px;
                }

                /* === Autocomplete === */
                .suggestion-name {
                    font-size: 0.85em;
                    font-family: monospace;
                    color: #d0d0d0;
                }
                .suggestion-count {
                    font-size: 0.75em;
                    font-family: monospace;
                    color: #707070;
                }
                .suggestion-cat {
                    font-size: 0.65em;
                    font-family: monospace;
                    font-weight: 700;
                    color: #909090;
                    text-transform: uppercase;
                }

                /* === Popovers (autocomplete, menus) === */
                popover contents {
                    background: #1a1a1a;
                    border: 1px solid #333333;
                    border-radius: 2px;
                    color: #d0d0d0;
                }
                popover row {
                    padding: 4px 8px;
                }
                popover row:hover {
                    background: #252525;
                }

                /* === Download dialog === */
                .download-file-row {
                    padding: 4px 0;
                    border-bottom: 1px solid #2a2a2a;
                }
                .download-file-row:last-child {
                    border-bottom: none;
                }
                .download-status-icon {
                    opacity: 0.8;
                }

                /* === Status page (empty / error) === */
                statuspage {
                    color: #a0a0a0;
                }
                statuspage title {
                    font-family: monospace;
                    font-weight: 700;
                    color: #d0d0d0;
                }
                statuspage description {
                    font-family: monospace;
                    font-size: 0.85em;
                    color: #808080;
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
