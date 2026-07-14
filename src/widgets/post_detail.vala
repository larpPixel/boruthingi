namespace Danbooru {
    /**
     * Detail view: full-bleed image stage on the left, slim info rail on the right.
     * No frames-in-boxes nesting — surface + rail only.
     */
    public class PostDetailView : Gtk.Box {
        public signal void back();
        public signal void tag_clicked(string tag);

        public Post post { get; set; }

        private Gtk.Label id_label;
        private Gtk.Picture picture;
        private Gtk.Spinner spinner;
        private Gtk.Label empty_label;
        private Gtk.Label rating_value;
        private Gtk.Label score_value;
        private Gtk.Label dims_value;
        private Gtk.Label file_size_value;
        private Gtk.Label source_value;
        private Gtk.Label pixiv_value;
        private Gtk.FlowBox tags_flow;
        private Gtk.Button open_button;
        private Gtk.Button download_button;
        private Api? current_api;
        private int64 loading_post_id = 0;

        public PostDetailView() {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        }

        construct {
            var detail_header = new AppBar(false);

            var back_btn = new Gtk.Button.from_icon_name("go-previous-symbolic");
            back_btn.tooltip_text = "Back to grid";
            back_btn.clicked.connect(() => back());

            id_label = new Gtk.Label("");
            id_label.add_css_class("bar-title");
            id_label.halign = Gtk.Align.START;
            id_label.valign = Gtk.Align.CENTER;
            id_label.hexpand = true;
            id_label.ellipsize = Pango.EllipsizeMode.END;

            open_button = new Gtk.Button.with_label("Open in Browser");
            open_button.tooltip_text = "Open post page in web browser";
            open_button.clicked.connect(on_open_browser);

            download_button = new Gtk.Button.with_label("Download Best Available");
            download_button.add_css_class("suggested-action");
            download_button.tooltip_text = "Download the highest quality available";
            download_button.clicked.connect(on_download_original);

            detail_header.pack_start(back_btn);
            detail_header.pack_start(id_label);
            detail_header.pack_end(open_button);
            detail_header.pack_end(download_button);
            append(detail_header);

            // Body: image stage | info rail
            var body = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            body.vexpand = true;
            body.hexpand = true;

            // --- Image stage (fills remaining space) ---
            var stage = new Gtk.Overlay();
            stage.hexpand = true;
            stage.vexpand = true;
            stage.add_css_class("detail-stage");

            picture = new Gtk.Picture();
            picture.content_fit = Gtk.ContentFit.CONTAIN;
            picture.hexpand = true;
            picture.vexpand = true;
            picture.can_shrink = true;
            stage.child = picture;

            spinner = new Gtk.Spinner();
            spinner.halign = Gtk.Align.CENTER;
            spinner.valign = Gtk.Align.CENTER;
            spinner.width_request = 32;
            spinner.height_request = 32;
            stage.add_overlay(spinner);

            empty_label = new Gtk.Label("No preview");
            empty_label.add_css_class("meta-label");
            empty_label.halign = Gtk.Align.CENTER;
            empty_label.valign = Gtk.Align.CENTER;
            empty_label.visible = false;
            stage.add_overlay(empty_label);

            body.append(stage);

            // --- Info rail ---
            var rail_scroll = new Gtk.ScrolledWindow();
            rail_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            rail_scroll.vexpand = true;
            rail_scroll.width_request = 300;
            rail_scroll.add_css_class("detail-rail");

            var rail = new Gtk.Box(Gtk.Orientation.VERTICAL, 14);
            rail.margin_start = 14;
            rail.margin_end = 14;
            rail.margin_top = 14;
            rail.margin_bottom = 14;

            var meta = new Gtk.Grid();
            meta.column_spacing = 12;
            meta.row_spacing = 6;
            meta.halign = Gtk.Align.FILL;

            int r = 0;
            add_meta_row(meta, ref r, "Rating", out rating_value);
            add_meta_row(meta, ref r, "Score", out score_value);
            add_meta_row(meta, ref r, "Dimensions", out dims_value);
            add_meta_row(meta, ref r, "File Size", out file_size_value);
            add_meta_row(meta, ref r, "Source", out source_value);
            add_meta_row(meta, ref r, "Pixiv ID", out pixiv_value);
            rail.append(meta);

            var tags_title = new Gtk.Label("Tags");
            tags_title.add_css_class("section-title");
            tags_title.halign = Gtk.Align.START;
            rail.append(tags_title);

            tags_flow = new Gtk.FlowBox();
            tags_flow.selection_mode = Gtk.SelectionMode.NONE;
            tags_flow.column_spacing = 6;
            tags_flow.row_spacing = 6;
            tags_flow.homogeneous = false;
            tags_flow.max_children_per_line = 20;
            tags_flow.min_children_per_line = 1;
            tags_flow.valign = Gtk.Align.START;
            tags_flow.halign = Gtk.Align.FILL;
            rail.append(tags_flow);

            rail_scroll.child = rail;
            body.append(rail_scroll);

            append(body);
        }

        private void add_meta_row(Gtk.Grid grid, ref int row, string label, out Gtk.Label value_label) {
            var lbl = new Gtk.Label(label);
            lbl.halign = Gtk.Align.START;
            lbl.valign = Gtk.Align.START;
            lbl.add_css_class("meta-label");

            value_label = new Gtk.Label("…");
            value_label.halign = Gtk.Align.START;
            value_label.hexpand = true;
            value_label.selectable = true;
            value_label.wrap = true;
            value_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            value_label.max_width_chars = 28;
            value_label.ellipsize = Pango.EllipsizeMode.END;
            value_label.lines = 3;
            value_label.add_css_class("meta-value");

            grid.attach(lbl, 0, row, 1, 1);
            grid.attach(value_label, 1, row, 1, 1);
            row++;
        }

        public void display_post(Post post, Api api) {
            this.post = post;
            this.current_api = api;
            loading_post_id = post.id;

            id_label.label = @"Post #$(post.id)";
            rating_value.label = post.display_rating;
            score_value.label = @"$(post.score)";
            dims_value.label = @"$(post.image_width) × $(post.image_height)";
            file_size_value.label = post.file_size_display;
            source_value.label = post.source != "" ? post.source : "—";
            source_value.tooltip_text = post.source;
            pixiv_value.label = post.pixiv_id >= 0 ? @"$(post.pixiv_id)" : "—";

            rebuild_tags();
            load_large_image.begin(api);
        }

        private void rebuild_tags() {
            while (true) {
                var child = tags_flow.get_child_at_index(0);
                if (child == null) break;
                tags_flow.remove(child);
            }

            // Artist / character / copyright first (most useful), then general, then meta.
            add_tag_buttons(post.tag_string_artist, "artist");
            add_tag_buttons(post.tag_string_character, "character");
            add_tag_buttons(post.tag_string_copyright, "copyright");
            add_tag_buttons(post.tag_string_general, "general");
            add_tag_buttons(post.tag_string_meta, "meta");
        }

        private void add_tag_buttons(string tag_string, string css_class) {
            if (tag_string.strip() == "") return;

            foreach (var raw in tag_string.split(" ")) {
                var tag = raw.strip();
                if (tag == "") continue;

                var btn = new Gtk.Button.with_label(tag.replace("_", " "));
                btn.add_css_class("tag-button");
                btn.add_css_class(css_class);
                btn.tooltip_text = @"Search for '$(tag)'";
                // Capture tag by value for the closure.
                var tag_copy = tag;
                btn.clicked.connect(() => tag_clicked(tag_copy));
                tags_flow.append(btn);
            }
        }

        private async void load_large_image(Api api) {
            int64 expected = loading_post_id;
            spinner.visible = true;
            spinner.start();
            empty_label.visible = false;
            picture.set_paintable(null);

            try {
                var url = post.large_url;
                if (url == "") {
                    if (expected == loading_post_id) {
                        spinner.stop();
                        spinner.visible = false;
                        empty_label.label = "No preview available";
                        empty_label.visible = true;
                    }
                    return;
                }

                var raw_bytes = yield api.download_bytes(url);
                if (expected != loading_post_id) return;

                var bytes = new GLib.Bytes(raw_bytes);
                var texture = Gdk.Texture.from_bytes(bytes);
                picture.set_paintable(texture);
            } catch (Error e) {
                if (expected != loading_post_id) return;
                warning("Failed to load image for post %s: %s", post.id.to_string(), e.message);
                empty_label.label = "Failed to load image";
                empty_label.visible = true;
            }

            if (expected == loading_post_id) {
                spinner.stop();
                spinner.visible = false;
            }
        }

        private void on_open_browser() {
            if (post == null) return;
            var launcher = new Gtk.UriLauncher(post.page_url);
            launcher.launch.begin(this.get_root() as Gtk.Window, null);
        }

        private void on_download_original() {
            if (post == null) return;

            var file_chooser = new Gtk.FileDialog();
            file_chooser.title = "Save Highest Quality Image";
            file_chooser.initial_name = @"$(post.id)_$(post.md5).$(post.download_file_ext)";

            var pictures = Environment.get_user_special_dir(GLib.UserDirectory.PICTURES);
            if (pictures != null) {
                file_chooser.initial_folder = GLib.File.new_for_path(pictures);
            }

            file_chooser.save.begin((Gtk.Window)this.get_root(), null, (obj, res) => {
                try {
                    var file = file_chooser.save.end(res);
                    if (file != null) {
                        download_original.begin(file.get_path());
                    }
                } catch (Error e) {
                    // User cancelled or dialog error
                }
            });
        }

        private async void download_original(string path) {
            if (current_api == null || post == null) return;
            try {
                var url = post.original_url;
                if (url == "") throw new IOError.NOT_FOUND("No URL");
                yield current_api.download_to_file(url, path);
            } catch (Error e) {
                warning("Download failed for post %s: %s", post.id.to_string(), e.message);
            }
        }
    }
}
