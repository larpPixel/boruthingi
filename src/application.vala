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
                /* ============================================================
                   Palette — cool slate + soft blue accent
                   bg #111318 · surface #181b22 · raised #232833
                   border #333a48 · text #e6e8ee · muted #8b93a2
                   accent #6ea8fe · on-accent #0b1020
                   ============================================================ */

                window {
                    background: #111318;
                    color: #e6e8ee;
                }

                /* ============================================================
                   AppBar — compact, even control rhythm
                   ============================================================ */
                .app-bar {
                    background: #181b22;
                    min-height: 40px;
                    padding: 5px 12px;
                    border-radius: 0;
                }
                .app-bar.top {
                    border-bottom: 1px solid #2a303c;
                    border-top: none;
                }
                .app-bar.bottom {
                    border-top: 1px solid #2a303c;
                    border-bottom: none;
                }

                .app-bar-sep {
                    background: #3a4252;
                    min-width: 1px;
                    min-height: 16px;
                    margin: 0 4px;
                    opacity: 1;
                }

                .bar-label {
                    font-size: 0.72em;
                    font-weight: 600;
                    color: #8b93a2;
                    letter-spacing: 0.3px;
                    margin-inline-start: 2px;
                    margin-inline-end: 0;
                }
                .bar-status {
                    font-size: 0.8em;
                    font-weight: 600;
                    color: #a8b0be;
                    min-width: 5.5em;
                    padding: 0 2px;
                }
                .bar-title {
                    font-size: 0.9em;
                    font-weight: 600;
                    color: #e6e8ee;
                }
                .section-title,
                .heading {
                    font-weight: 600;
                    font-size: 0.9em;
                    color: #e6e8ee;
                }

                /* One control height across the bar */
                .app-bar entry,
                .app-bar searchentry,
                .app-bar spinbutton,
                .app-bar dropdown,
                .app-bar button {
                    min-height: 28px;
                    font-size: 0.82em;
                }
                .app-bar button {
                    padding: 0 10px;
                    min-width: 28px;
                }
                /* Icon-only buttons (search, clear, refresh, back) stay square */
                .app-bar button image {
                    margin: 0;
                    padding: 0;
                }
                .app-bar switch {
                    margin: 0;
                }
                .app-bar dropdown {
                    min-width: 0;
                }
                .app-bar spinbutton {
                    min-width: 72px;
                }
                .app-bar searchentry,
                .app-bar entry {
                    padding: 0 8px;
                }

                /* ============================================================
                   Inputs
                   ============================================================ */
                entry,
                searchentry,
                spinbutton,
                dropdown {
                    background: #232833;
                    color: #e6e8ee;
                    border: 1px solid #333a48;
                    border-radius: 5px;
                    font-size: 0.82em;
                    min-height: 28px;
                    box-shadow: none;
                }
                entry:focus,
                searchentry:focus,
                spinbutton:focus,
                dropdown:focus,
                entry:focus-within,
                searchentry:focus-within,
                spinbutton:focus-within,
                dropdown:focus-within {
                    border-color: #6ea8fe;
                    outline: none;
                    box-shadow: 0 0 0 2px alpha(#6ea8fe, 0.22);
                }
                entry selection,
                searchentry selection {
                    background: alpha(#6ea8fe, 0.35);
                    color: #ffffff;
                }

                /* ============================================================
                   Buttons
                   ============================================================ */
                button {
                    background: #232833;
                    color: #e6e8ee;
                    border: 1px solid #333a48;
                    border-radius: 5px;
                    font-size: 0.82em;
                    padding: 0 10px;
                    min-height: 28px;
                    box-shadow: none;
                }
                button:hover {
                    background: #2c3240;
                    border-color: #454e60;
                }
                button:active {
                    background: #1c2029;
                }
                button:disabled {
                    opacity: 0.4;
                }
                button.suggested-action {
                    background: #6ea8fe;
                    color: #0b1020;
                    border-color: #5a96eb;
                    font-weight: 600;
                }
                button.suggested-action:hover {
                    background: #8bbcff;
                    border-color: #6ea8fe;
                }
                button.suggested-action:active {
                    background: #5a96eb;
                }
                button.suggested-action:disabled {
                    background: #2a3140;
                    border-color: #333a48;
                    color: #6b7384;
                    opacity: 1;
                }

                /* ============================================================
                   Switches
                   ============================================================ */
                switch {
                    background: #232833;
                    border: 1px solid #333a48;
                    border-radius: 12px;
                    min-width: 36px;
                    min-height: 20px;
                }
                switch:checked {
                    background: #6ea8fe;
                    border-color: #5a96eb;
                }
                switch:hover {
                    border-color: #454e60;
                }
                switch:checked:hover {
                    background: #8bbcff;
                    border-color: #6ea8fe;
                }
                switch slider {
                    background: #e6e8ee;
                    border-radius: 10px;
                    min-width: 16px;
                    min-height: 16px;
                    box-shadow: none;
                }

                /* ============================================================
                   Thumbnail grid
                   ============================================================ */
                .post-grid {
                    background: transparent;
                }
                .post-grid > flowboxchild {
                    padding: 0;
                    background: transparent;
                    border: none;
                    box-shadow: none;
                }
                .thumbnail-card {
                    background: #0e1015;
                    border: 1px solid #2a303c;
                    border-radius: 4px;
                    transition: border-color 80ms ease;
                }
                .thumbnail-card:hover {
                    border-color: #6ea8fe;
                }
                .thumbnail-card.selected {
                    border-color: #6ea8fe;
                    box-shadow: inset 0 0 0 1px #6ea8fe;
                }
                .thumbnail-image {
                    background: #0e1015;
                }

                /* ============================================================
                   Badges & pills
                   ============================================================ */
                .badge {
                    padding: 1px 5px;
                    border-radius: 3px;
                    font-size: 0.65em;
                    font-weight: 700;
                    letter-spacing: 0.3px;
                    text-transform: uppercase;
                    color: #0b1020;
                    font-family: monospace;
                }
                .badge.s { background: #6bbf8a; }
                .badge.q { background: #e0b44f; }
                .badge.e { background: #e06c75; }

                .info-pill {
                    padding: 1px 5px;
                    border-radius: 3px;
                    font-size: 0.65em;
                    font-weight: 600;
                    font-family: monospace;
                    background: alpha(#0b1020, 0.78);
                    color: #e6e8ee;
                    letter-spacing: 0.2px;
                }

                /* ============================================================
                   Detail — stage + rail
                   ============================================================ */
                .detail-stage {
                    background: #0a0c10;
                }
                .detail-rail {
                    background: #181b22;
                    border-left: 1px solid #2a303c;
                    min-width: 280px;
                }
                .meta-label {
                    font-size: 0.7em;
                    font-weight: 600;
                    font-family: monospace;
                    color: #8b93a2;
                    text-transform: uppercase;
                    letter-spacing: 0.35px;
                }
                .meta-value {
                    font-size: 0.85em;
                    font-family: monospace;
                    color: #e6e8ee;
                }

                /* ============================================================
                   Tags
                   ============================================================ */
                .tag-button {
                    padding: 2px 8px;
                    font-size: 0.78em;
                    font-family: monospace;
                    border-radius: 4px;
                    background: #232833;
                    border: 1px solid #333a48;
                    color: #e6e8ee;
                    min-height: 0;
                }
                .tag-button:hover {
                    background: #2c3240;
                    border-color: #6ea8fe;
                }
                .tag-button.artist {
                    border-color: alpha(#e0b44f, 0.55);
                    color: #f0d08a;
                }
                .tag-button.character {
                    border-color: alpha(#6bbf8a, 0.55);
                    color: #9fd9b4;
                }
                .tag-button.copyright {
                    border-color: alpha(#c792ea, 0.5);
                    color: #d4b0f0;
                }
                .tag-button.meta {
                    border-color: alpha(#8b93a2, 0.45);
                    color: #a8b0be;
                }

                /* ============================================================
                   Selection checkbox
                   ============================================================ */
                .selection-overlay {
                    background: alpha(#0b1020, 0.6);
                    border-radius: 4px;
                }

                /* ============================================================
                   Autocomplete
                   ============================================================ */
                .suggestion-name {
                    font-size: 0.85em;
                    color: #e6e8ee;
                }
                .suggestion-count {
                    font-size: 0.75em;
                    font-family: monospace;
                    color: #6b7384;
                }
                .suggestion-cat {
                    font-size: 0.65em;
                    font-family: monospace;
                    font-weight: 700;
                    color: #8b93a2;
                    text-transform: uppercase;
                }

                popover contents {
                    background: #181b22;
                    border: 1px solid #333a48;
                    border-radius: 6px;
                    color: #e6e8ee;
                    box-shadow: 0 8px 24px alpha(#000000, 0.45);
                }
                popover row {
                    padding: 6px 10px;
                    border-radius: 4px;
                }
                popover row:hover {
                    background: #232833;
                }

                /* ============================================================
                   Download dialog
                   ============================================================ */
                .download-file-row {
                    padding: 6px 0;
                    border-bottom: 1px solid #2a303c;
                }
                .download-file-row:last-child {
                    border-bottom: none;
                }
                .download-status-icon {
                    opacity: 0.85;
                }

                /* ============================================================
                   Status page
                   ============================================================ */
                statuspage {
                    color: #a8b0be;
                }
                statuspage title {
                    font-weight: 600;
                    color: #e6e8ee;
                }
                statuspage description {
                    font-size: 0.9em;
                    color: #8b93a2;
                }

                actionbar,
                headerbar {
                    background: #181b22;
                    border-color: #2a303c;
                    box-shadow: none;
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
            var style_manager = Adw.StyleManager.get_default();
            style_manager.color_scheme = Adw.ColorScheme.PREFER_DARK;

            setup_css();

            var window = new MainWindow(this);
            window.present();
        }
    }
}
