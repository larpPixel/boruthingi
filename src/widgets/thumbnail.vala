namespace Danbooru {
    public class ThumbnailWidget : Gtk.Box {
        public signal void clicked(Post post);
        public signal void selection_toggled(Post post, bool selected);

        public Post post { get; construct; }
        public bool is_selected { get; set; default = false; }

        private Gtk.Image image_widget;
        private Gtk.Label score_label;
        private Gtk.Label dims_label;
        private Gtk.CheckButton check_button;
        private Gtk.Overlay overlay;
        private Gtk.Box container;
        private int preview_w;
        private int preview_h;

        public ThumbnailWidget(Post post, PreviewSize size = PreviewSize.MEDIUM) {
            Object(post: post, orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            set_preview_size(size);
        }

        construct {
            this.hexpand = false;
            this.vexpand = false;

            add_css_class("thumbnail-card");

            overlay = new Gtk.Overlay();
            overlay.width_request = preview_w;
            overlay.height_request = preview_h;

            image_widget = new Gtk.Image();
            image_widget.pixel_size = preview_w;
            image_widget.set_size_request(preview_w, preview_h);
            image_widget.add_css_class("thumbnail-image");
            image_widget.set_from_icon_name("image-x-generic-symbolic");

            overlay.child = image_widget;

            // Selection checkbox (top-left)
            check_button = new Gtk.CheckButton();
            check_button.halign = Gtk.Align.START;
            check_button.valign = Gtk.Align.START;
            check_button.margin_start = 4;
            check_button.margin_top = 4;
            check_button.add_css_class("selection-overlay");
            check_button.toggled.connect(() => {
                is_selected = check_button.active;
                selection_toggled(post, is_selected);
                if (is_selected) {
                    container.add_css_class("selected");
                } else {
                    container.remove_css_class("selected");
                }
            });
            overlay.add_overlay(check_button);

            // Rating badge (top-right)
            var rating_label = new Gtk.Label(post.display_rating);
            rating_label.halign = Gtk.Align.END;
            rating_label.valign = Gtk.Align.START;
            rating_label.margin_end = 4;
            rating_label.margin_top = 4;
            rating_label.add_css_class("badge");
            rating_label.add_css_class(post.rating_css_key);
            overlay.add_overlay(rating_label);

            // Score pill (bottom-left)
            score_label = new Gtk.Label(@"★$(post.score)");
            score_label.halign = Gtk.Align.START;
            score_label.valign = Gtk.Align.END;
            score_label.margin_start = 4;
            score_label.margin_bottom = 4;
            score_label.add_css_class("info-pill");
            overlay.add_overlay(score_label);

            // Dimensions pill (bottom-right)
            dims_label = new Gtk.Label(@"$(post.image_width)×$(post.image_height)");
            dims_label.halign = Gtk.Align.END;
            dims_label.valign = Gtk.Align.END;
            dims_label.margin_end = 4;
            dims_label.margin_bottom = 4;
            dims_label.add_css_class("info-pill");
            overlay.add_overlay(dims_label);

            this.append(overlay);

            // Click gesture on image
            var gesture = new Gtk.GestureClick();
            gesture.pressed.connect((n_press, x, y) => {
                clicked(post);
            });
            image_widget.add_controller(gesture);

            container = this;
        }

        public void set_preview_size(PreviewSize size) {
            preview_w = Config.preview_width_for_size(size);
            preview_h = Config.preview_height_for_size(size);
            this.width_request = Config.thumbnail_width_for_size(size);
            if (overlay != null) {
                overlay.width_request = preview_w;
                overlay.height_request = preview_h;
            }
            if (image_widget != null) {
                image_widget.pixel_size = preview_w;
                image_widget.set_size_request(preview_w, preview_h);
            }
        }

        public void set_selected(bool selected) {
            if (check_button.active != selected) {
                check_button.active = selected;
            }
        }

        public async void load_thumbnail(Api api) {
            // Check cache first
            string? cached = api.get_cached_thumbnail(post.md5, post.file_ext);
            if (cached != null) {
                try {
                    var cached_file = GLib.File.new_for_path(cached);
                    string? etag;
                    var bytes = yield cached_file.load_bytes_async(null, out etag);
                    var texture = Gdk.Texture.from_bytes(bytes);
                    image_widget.set_from_paintable(texture);
                    return;
                } catch (Error e) {
                    // Fall through to download
                }
            }

            // Download and cache
            try {
                var url = post.thumbnail_url;
                if (url == "") return;
                var raw_bytes = yield api.download_bytes(url);
                var bytes = new GLib.Bytes(raw_bytes);

                var texture = Gdk.Texture.from_bytes(bytes);
                image_widget.set_from_paintable(texture);

                // Cache async (fire and forget)
                download_thumbnail_to_cache.begin(api, url);

            } catch (Error e) {
                warning("Failed to load thumbnail for post %lld: %s", post.id, e.message);
            }
        }

        private async void download_thumbnail_to_cache(Api api, string url) {
            try {
                yield api.cache_thumbnail(url, post.md5, post.file_ext);
            } catch (Error e) {
                // Cache miss is non-critical
            }
        }
    }
}
