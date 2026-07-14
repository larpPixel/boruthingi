namespace Danbooru {
    /** Thumbnail card: image surface with badges overlaid. */
    public class ThumbnailWidget : Gtk.Box {
        public signal void clicked(Post post);
        public signal void selection_toggled(Post post, bool selected);

        public Post post { get; construct; }

        private Gtk.Image image_widget;
        private Gtk.CheckButton check_button;
        private Gtk.Overlay overlay;
        private int load_gen = 0;

        public ThumbnailWidget(Post post, PreviewSize size = PreviewSize.MEDIUM) {
            Object(post: post, orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            set_preview_size(size);
        }

        construct {
            hexpand = false;
            vexpand = false;
            overflow = Gtk.Overflow.HIDDEN;
            add_css_class("thumbnail-card");

            overlay = new Gtk.Overlay();

            image_widget = new Gtk.Image();
            image_widget.add_css_class("thumbnail-image");
            image_widget.set_from_icon_name("image-x-generic-symbolic");
            overlay.child = image_widget;

            check_button = new Gtk.CheckButton();
            check_button.halign = Gtk.Align.START;
            check_button.valign = Gtk.Align.START;
            check_button.margin_start = 4;
            check_button.margin_top = 4;
            check_button.add_css_class("selection-overlay");
            check_button.toggled.connect(() => {
                if (check_button.active) {
                    add_css_class("selected");
                } else {
                    remove_css_class("selected");
                }
                selection_toggled(post, check_button.active);
            });
            overlay.add_overlay(check_button);

            var rating_label = new Gtk.Label(post.display_rating);
            rating_label.halign = Gtk.Align.END;
            rating_label.valign = Gtk.Align.START;
            rating_label.margin_end = 4;
            rating_label.margin_top = 4;
            rating_label.add_css_class("badge");
            rating_label.add_css_class(post.rating_css_key);
            overlay.add_overlay(rating_label);

            var score_label = new Gtk.Label(@"★$(post.score)");
            score_label.halign = Gtk.Align.START;
            score_label.valign = Gtk.Align.END;
            score_label.margin_start = 4;
            score_label.margin_bottom = 4;
            score_label.add_css_class("info-pill");
            overlay.add_overlay(score_label);

            var dims_label = new Gtk.Label(@"$(post.image_width)×$(post.image_height)");
            dims_label.halign = Gtk.Align.END;
            dims_label.valign = Gtk.Align.END;
            dims_label.margin_end = 4;
            dims_label.margin_bottom = 4;
            dims_label.add_css_class("info-pill");
            overlay.add_overlay(dims_label);

            append(overlay);

            // Image only — overlays keep their own events.
            var gesture = new Gtk.GestureClick();
            gesture.set_button(1);
            gesture.released.connect(() => clicked(post));
            image_widget.add_controller(gesture);
        }

        public void set_preview_size(PreviewSize size) {
            int px = Config.preview_px(size);
            width_request = px;
            height_request = px;
            if (overlay != null) {
                overlay.width_request = px;
                overlay.height_request = px;
            }
            if (image_widget != null) {
                image_widget.pixel_size = px;
                image_widget.set_size_request(px, px);
            }
        }

        public void set_selected(bool selected) {
            if (check_button.active != selected) {
                check_button.active = selected;
            }
        }

        public async void load_thumbnail(Api api) {
            int gen = ++load_gen;

            string? cached = api.get_cached_thumbnail(post.md5, post.file_ext);
            if (cached != null) {
                try {
                    var file = GLib.File.new_for_path(cached);
                    string? etag;
                    var bytes = yield file.load_bytes_async(null, out etag);
                    if (gen != load_gen) return;
                    image_widget.set_from_paintable(Gdk.Texture.from_bytes(bytes));
                    return;
                } catch (Error e) {
                    // Fall through to download
                }
            }

            try {
                var url = post.thumbnail_url;
                if (url == "") return;

                var raw = yield api.download_bytes(url);
                if (gen != load_gen) return;

                image_widget.set_from_paintable(Gdk.Texture.from_bytes(new GLib.Bytes(raw)));
                cache_later.begin(api, url);
            } catch (Error e) {
                if (gen != load_gen) return;
                warning("Failed to load thumbnail for post %s: %s", post.id.to_string(), e.message);
            }
        }

        private async void cache_later(Api api, string url) {
            try {
                yield api.cache_thumbnail(url, post.md5, post.file_ext);
            } catch (Error e) {
                // Non-critical
            }
        }
    }
}
