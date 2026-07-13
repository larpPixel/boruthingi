namespace Danbooru {
    public class ThumbnailWidget : Gtk.Box {
        public signal void clicked(Post post);
        public signal void selection_toggled(Post post, bool selected);

        public Post post { get; construct; }
        public bool is_selected { get; set; default = false; }

        private Gtk.Image image_widget;
        private Gtk.Label score_label;
        private Gtk.Label rating_label;
        private Gtk.CheckButton check_button;
        private Gtk.Overlay overlay;
        private Gtk.Box container;

        public ThumbnailWidget(Post post) {
            Object(post: post, orientation: Gtk.Orientation.VERTICAL, spacing: 1);
        }

        construct {
            this.width_request = Config.THUMBNAIL_WIDTH;
            this.hexpand = false;

            add_css_class("thumbnail-card");

            // Image overlay container
            overlay = new Gtk.Overlay();

            image_widget = new Gtk.Image();
            image_widget.pixel_size = Config.PREVIEW_WIDTH;
            image_widget.set_size_request(Config.PREVIEW_WIDTH, Config.PREVIEW_HEIGHT);
            image_widget.add_css_class("thumbnail-image");

            // Placeholder
            image_widget.set_from_icon_name("image-x-generic-symbolic");

            overlay.child = image_widget;

            // Check button for selection (top-left)
            check_button = new Gtk.CheckButton();
            check_button.halign = Gtk.Align.START;
            check_button.valign = Gtk.Align.START;
            check_button.margin_start = 4;
            check_button.margin_top = 4;
            check_button.add_css_class("selection-check");
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
            rating_label = new Gtk.Label(post.display_rating);
            rating_label.halign = Gtk.Align.END;
            rating_label.valign = Gtk.Align.START;
            rating_label.margin_end = 4;
            rating_label.margin_top = 4;
            rating_label.add_css_class(post.rating_color_css);
            overlay.add_overlay(rating_label);

            this.append(overlay);

            // Info bar
            var info_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            info_box.homogeneous = false;

            score_label = new Gtk.Label(@"★ $(post.score)");
            score_label.halign = Gtk.Align.START;
            score_label.add_css_class("score-label");

            var dims_label = new Gtk.Label(@"$(post.image_width)×$(post.image_height)");
            dims_label.halign = Gtk.Align.END;
            dims_label.hexpand = true;
            dims_label.add_css_class("dims-label");

            info_box.append(score_label);
            info_box.append(dims_label);
            this.append(info_box);

            // Click gesture
            var gesture = new Gtk.GestureClick();
            gesture.pressed.connect((n_press, x, y) => {
                clicked(post);
            });
            image_widget.add_controller(gesture);

            container = this;
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

                // Cache asynchronously (fire and forget)
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
