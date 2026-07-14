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
                   Shared design tokens (dark, dense, gold accent)
                   ============================================================ */
                /* bg: #141414 surface: #1a1a1a raised: #222
                   border: #2e2e2e hover-border: #3a3a3a
                   text: #d0d0d0 muted: #888 accent: #b8860b */

                window {
                    background: #141414;
                    color: #d0d0d0;
                }

                /* ============================================================
                   AppBar — one chrome for top, bottom, and detail header
                   ============================================================ */
                .app-bar {
                    background: #1a1a1a;
                    min-height: 44px;
                    padding: 8px 14px;
                    border-radius: 0;
                }
                .app-bar.top {
                    border-bottom: 1px solid #2e2e2e;
                    border-top: none;
                }
                .app-bar.bottom {
                    border-top: 1px solid #2e2e2e;
                    border-bottom: none;
                }

                .app-bar-sep {
                    background: #2e2e2e;
                    min-width: 1px;
                    min-height: 18px;
                    margin: 0 2px;
                    opacity: 1;
                }

                /* Labels that live inside bars */
                .bar-label {
                    font-size: 0.75em;
                    font-family: monospace;
                    font-weight: 600;
                    color: #888888;
                    letter-spacing: 0.2px;
                }
                .bar-status {
                    font-size: 0.8em;
                    font-family: monospace;
                    font-weight: 600;
                    color: #a8a8a8;
                    min-width: 6em;
                }
                .bar-title {
                    font-size: 0.9em;
                    font-family: monospace;
                    font-weight: 700;
                    color: #d0d0d0;
                }
                .section-title,
                .heading {
                    font-weight: 700;
                    font-size: 0.95em;
                    font-family: monospace;
                    color: #d0d0d0;
                }

                /* Controls inside bars share one height */
                .app-bar entry,
                .app-bar searchentry,
                .app-bar spinbutton,
                .app-bar dropdown,
                .app-bar button {
                    min-height: 30px;
                }
                .app-bar switch {
                    margin-top: 0;
                    margin-bottom: 0;
                }

                /* ============================================================
                   Inputs
                   ============================================================ */
                entry,
                searchentry,
                spinbutton,
                dropdown {
                    background: #222222;
                    color: #d0d0d0;
                    border: 1px solid #2e2e2e;
                    border-radius: 3px;
                    font-family: monospace;
                    font-size: 0.85em;
                    min-height: 30px;
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
                    border-color: #b8860b;
                    outline: none;
                    box-shadow: 0 0 0 1px alpha(#b8860b, 0.25);
                }
                entry selection,
                searchentry selection {
                    background: alpha(#b8860b, 0.35);
                    color: #ffffff;
                }

                /* ============================================================
                   Buttons
                   ============================================================ */
                button {
                    background: #222222;
                    color: #d0d0d0;
                    border: 1px solid #2e2e2e;
                    border-radius: 3px;
                    font-family: monospace;
                    font-size: 0.85em;
                    padding: 4px 12px;
                    min-height: 30px;
                    box-shadow: none;
                }
                button:hover {
                    background: #2a2a2a;
                    border-color: #3a3a3a;
                }
                button:active {
                    background: #1f1f1f;
                }
                button:disabled {
                    opacity: 0.45;
                }
                button.suggested-action {
                    background: #b8860b;
                    color: #111111;
                    border-color: #9a7209;
                    font-weight: 700;
                }
                button.suggested-action:hover {
                    background: #d4a017;
                    border-color: #b8860b;
                }
                button.suggested-action:active {
                    background: #9a7209;
                }
                button.suggested-action:disabled {
                    background: #5a4a1a;
                    border-color: #5a4a1a;
                    color: #222222;
                    opacity: 1;
                }

                /* ============================================================
                   Switches
                   ============================================================ */
                switch {
                    background: #222222;
                    border: 1px solid #2e2e2e;
                    border-radius: 14px;
                    min-width: 40px;
                    min-height: 22px;
                }
                switch:checked {
                    background: #b8860b;
                    border-color: #9a7209;
                }
                switch:hover {
                    border-color: #3a3a3a;
                }
                switch:checked:hover {
                    background: #d4a017;
                    border-color: #b8860b;
                }
                switch slider {
                    background: #d0d0d0;
                    border-radius: 12px;
                    min-width: 18px;
                    min-height: 18px;
                    box-shadow: none;
                }

                /* ============================================================
                   Thumbnail grid — edge-to-edge flow, cards are the only surface
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
                    background: #111111;
                    border: 1px solid #2e2e2e;
                    border-radius: 3px;
                    transition: border-color 80ms ease;
                }
                .thumbnail-card:hover {
                    border-color: #b8860b;
                }
                .thumbnail-card.selected {
                    border-color: #b8860b;
                    box-shadow: inset 0 0 0 1px #b8860b;
                }
                .thumbnail-image {
                    background: #111111;
                }

                /* ============================================================
                   Badges & pills
                   ============================================================ */
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
                .badge.s { background: #6b8e6b; }
                .badge.q { background: #b8860b; }
                .badge.e { background: #a52a2a; }

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

                /* ============================================================
                   Detail — stage + rail, not boxes-in-frames
                   ============================================================ */
                .detail-stage {
                    background: #0e0e0e;
                }
                .detail-rail {
                    background: #1a1a1a;
                    border-left: 1px solid #2e2e2e;
                    min-width: 280px;
                }
                .meta-label {
                    font-size: 0.72em;
                    font-weight: 600;
                    font-family: monospace;
                    color: #888888;
                    text-transform: uppercase;
                    letter-spacing: 0.3px;
                }
                .meta-value {
                    font-size: 0.85em;
                    font-family: monospace;
                    color: #d0d0d0;
                }

                /* ============================================================
                   Tags — flat chips in one flow
                   ============================================================ */
                .tag-button {
                    padding: 3px 9px;
                    font-size: 0.78em;
                    font-family: monospace;
                    border-radius: 3px;
                    background: #222222;
                    border: 1px solid #2e2e2e;
                    color: #d0d0d0;
                    min-height: 0;
                }
                .tag-button:hover {
                    background: #2a2a2a;
                    border-color: #b8860b;
                }
                .tag-button.artist {
                    border-color: alpha(#cd853f, 0.55);
                    color: #e0b888;
                }
                .tag-button.character {
                    border-color: alpha(#6b8e6b, 0.55);
                    color: #a8c8a8;
                }
                .tag-button.copyright {
                    border-color: alpha(#a0522d, 0.5);
                    color: #c89878;
                }
                .tag-button.meta {
                    border-color: alpha(#808080, 0.45);
                    color: #a0a0a0;
                }
                /* ============================================================
                   Selection checkbox on thumbnails
                   ============================================================ */
                .selection-overlay {
                    background: rgba(0, 0, 0, 0.55);
                    border-radius: 3px;
                }

                /* ============================================================
                   Autocomplete
                   ============================================================ */
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

                popover contents {
                    background: #1a1a1a;
                    border: 1px solid #2e2e2e;
                    border-radius: 3px;
                    color: #d0d0d0;
                    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.45);
                }
                popover row {
                    padding: 5px 10px;
                    border-radius: 2px;
                }
                popover row:hover {
                    background: #252525;
                }

                /* ============================================================
                   Download dialog
                   ============================================================ */
                .download-file-row {
                    padding: 6px 0;
                    border-bottom: 1px solid #2e2e2e;
                }
                .download-file-row:last-child {
                    border-bottom: none;
                }
                .download-status-icon {
                    opacity: 0.8;
                }

                /* ============================================================
                   Status page (empty / error)
                   ============================================================ */
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
                    color: #888888;
                }

                /* Kill Libadwaita / GTK default chrome that fights us */
                actionbar,
                headerbar {
                    background: #1a1a1a;
                    border-color: #2e2e2e;
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
