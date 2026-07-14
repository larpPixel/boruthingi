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
                   AppBar — fixed control height (32px), even padding
                   ============================================================ */
                .app-bar {
                    background: #181b22;
                    padding: 6px 12px;
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
                    min-height: 18px;
                    margin: 0 2px;
                }

                .bar-label {
                    font-size: 0.78em;
                    font-weight: 500;
                    color: #8b93a2;
                }
                .bar-status {
                    font-size: 0.82em;
                    font-weight: 500;
                    color: #a8b0be;
                    min-width: 5em;
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

                /*
                 * Fixed 32px control height.
                 * DropDown: style ONLY the inner toggle button — styling both
                 * the shell and the button draws double borders / offset rings.
                 */
                .app-bar button.bar-control,
                .app-bar entry.bar-control,
                .app-bar searchentry.bar-control {
                    min-height: 32px;
                    padding: 0 12px;
                    font-size: 0.84em;
                    border-radius: 6px;
                }
                .app-bar button.bar-icon {
                    min-width: 32px;
                    max-width: 32px;
                    padding: 0;
                }
                .app-bar button.bar-icon image {
                    margin: 0;
                    -gtk-icon-size: 16px;
                }
                .app-bar searchentry.bar-control {
                    padding: 0 10px;
                }
                .app-bar searchentry.bar-control > image,
                .app-bar searchentry.bar-control > text {
                    margin: 0;
                    min-height: 0;
                }
                /* Shell is invisible; chrome lives on the child button only */
                .app-bar dropdown.bar-control {
                    background: transparent;
                    border: none;
                    box-shadow: none;
                    padding: 0;
                    margin: 0;
                    min-height: 32px;
                    border-radius: 0;
                }
                .app-bar dropdown.bar-control > button {
                    min-height: 32px;
                    padding: 0 10px;
                    font-size: 0.84em;
                    border-radius: 6px;
                }
                .app-bar dropdown.bar-control > button > box {
                    margin: 0;
                    padding: 0;
                }
                .app-bar switch {
                    margin: 0;
                    min-width: 38px;
                    min-height: 22px;
                }

                /* ============================================================
                   Inputs
                   ============================================================ */
                entry,
                searchentry,
                spinbutton {
                    background: #232833;
                    color: #e6e8ee;
                    border: 1px solid #333a48;
                    border-radius: 6px;
                    font-size: 0.84em;
                    min-height: 32px;
                    box-shadow: none;
                    outline: none;
                }

                /* DropDown shell has no chrome */
                dropdown {
                    background: transparent;
                    color: #e6e8ee;
                    border: none;
                    border-radius: 0;
                    box-shadow: none;
                    outline: none;
                    padding: 0;
                    margin: 0;
                    min-height: 0;
                }
                /* Only the toggle is a real control surface */
                dropdown > button {
                    background: #232833;
                    color: #e6e8ee;
                    border: 1px solid #333a48;
                    border-radius: 6px;
                    font-size: 0.84em;
                    min-height: 32px;
                    padding: 0 10px;
                    box-shadow: none;
                    outline: none;
                }
                dropdown > button:hover {
                    background: #2c3240;
                    border-color: #454e60;
                }
                dropdown > button:checked {
                    background: #2c3240;
                    border-color: #6ea8fe;
                }

                entry:focus,
                searchentry:focus,
                spinbutton:focus,
                entry:focus-within,
                searchentry:focus-within,
                spinbutton:focus-within {
                    border-color: #6ea8fe;
                    outline: none;
                    box-shadow: none;
                }
                dropdown > button:focus {
                    border-color: #6ea8fe;
                    outline: none;
                    box-shadow: none;
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
                    border-radius: 6px;
                    font-size: 0.84em;
                    padding: 0 12px;
                    min-height: 32px;
                    box-shadow: none;
                    outline: none;
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
                button:focus {
                    border-color: #6ea8fe;
                    outline: none;
                    box-shadow: none;
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
                button.suggested-action:focus {
                    border-color: #8bbcff;
                    outline: none;
                    box-shadow: none;
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
                    border-radius: 11px;
                    min-width: 38px;
                    min-height: 22px;
                    box-shadow: none;
                    outline: none;
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
                switch:focus {
                    border-color: #6ea8fe;
                    outline: none;
                    box-shadow: none;
                }
                switch slider {
                    background: #e6e8ee;
                    border-radius: 10px;
                    min-width: 16px;
                    min-height: 16px;
                    box-shadow: none;
                    margin: 2px;
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
