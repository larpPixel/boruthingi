namespace Danbooru {
    public class PostDetailView : Gtk.Box {
        public signal void back();
        public signal void tag_clicked(string tag);

        public Post post { get; set; }

        private Gtk.Image image_widget;
        private Gtk.Label id_label;
        private Gtk.Label rating_value;
        private Gtk.Label score_value;
        private Gtk.Label dims_value;
        private Gtk.Label file_size_value;
        private Gtk.Label source_value;
        private Gtk.Label pixiv_value;
        private Gtk.Box tags_container;
        private Gtk.Button open_button;
        private Gtk.Button download_button;
        private Gtk.Spinner spinner;
        private Api? current_api;

        public PostDetailView() {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        }

        construct {
            // Detail header — styled like the main app toolbar
            var detail_clamp = new Adw.Clamp();
            detail_clamp.maximum_size = 1240;
            detail_clamp.tightening_threshold = 800;
            detail_clamp.margin_start = 12;
            detail_clamp.margin_end = 12;
            detail_clamp.margin_top = 8;
            detail_clamp.margin_bottom = 0;

            var detail_header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            detail_header.add_css_class("app-toolbar");

            var back_btn = new Gtk.Button.from_icon_name("go-previous-symbolic");
            back_btn.tooltip_text = "Back to grid";
            back_btn.clicked.connect(() => back());

            id_label = new Gtk.Label("");
            id_label.add_css_class("detail-id");
            id_label.hexpand = true;
            id_label.halign = Gtk.Align.START;

            open_button = new Gtk.Button.with_label("Open in Browser");
            open_button.tooltip_text = "Open post page in web browser";
            open_button.clicked.connect(on_open_browser);

            download_button = new Gtk.Button.with_label("Download Best Available");
            download_button.add_css_class("suggested-action");
            download_button.tooltip_text = "Download the highest quality available";
            download_button.clicked.connect(on_download_original);

            detail_header.append(back_btn);
            detail_header.append(id_label);
            detail_header.append(open_button);
            detail_header.append(download_button);

            detail_clamp.child = detail_header;
            this.append(detail_clamp);

            // Scrollable content
            var scrolled = new Gtk.ScrolledWindow();
            scrolled.vexpand = true;
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

            var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            content.margin_start = 12;
            content.margin_end = 12;
            content.margin_top = 12;
            content.margin_bottom = 12;

            // Image
            var image_frame = new Gtk.Frame(null);
            image_frame.add_css_class("image-frame");

            spinner = new Gtk.Spinner();
            spinner.start();

            image_widget = new Gtk.Image();
            image_widget.vexpand = false;
            image_widget.hexpand = true;
            image_widget.pixel_size = 800;
            image_widget.add_css_class("detail-image");

            var image_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            image_box.halign = Gtk.Align.CENTER;
            image_box.append(spinner);
            image_box.append(image_widget);
            image_frame.child = image_box;
            content.append(image_frame);

            // Metadata grid
            var meta_grid = new Gtk.Grid();
            meta_grid.column_spacing = 16;
            meta_grid.row_spacing = 4;
            meta_grid.margin_top = 4;
            meta_grid.margin_start = 4;

            int r = 0;
            add_meta_row(meta_grid, ref r, "Rating", out rating_value);
            add_meta_row(meta_grid, ref r, "Score", out score_value);
            add_meta_row(meta_grid, ref r, "Dimensions", out dims_value);
            add_meta_row(meta_grid, ref r, "File Size", out file_size_value);
            add_meta_row(meta_grid, ref r, "Source", out source_value);
            add_meta_row(meta_grid, ref r, "Pixiv ID", out pixiv_value);

            content.append(meta_grid);

            // Tags
            tags_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            tags_container.margin_top = 8;

            var tags_header = new Gtk.Label("Tags");
            tags_header.add_css_class("detail-id");
            tags_header.halign = Gtk.Align.START;
            tags_container.append(tags_header);

            content.append(tags_container);
            scrolled.child = content;
            this.append(scrolled);
        }

        private void add_meta_row(Gtk.Grid grid, ref int row, string label, out Gtk.Label value_label) {
            var lbl = new Gtk.Label(@"$(label):");
            lbl.halign = Gtk.Align.END;
            lbl.add_css_class("meta-label");
            lbl.hexpand = false;

            value_label = new Gtk.Label("...");
            value_label.halign = Gtk.Align.START;
            value_label.hexpand = true;
            value_label.selectable = true;
            value_label.wrap = true;
            value_label.add_css_class("meta-value");

            grid.attach(lbl, 0, row, 1, 1);
            grid.attach(value_label, 1, row, 1, 1);
            row++;
        }

        public void display_post(Post post, Api api) {
            this.post = post;
            this.current_api = api;

            id_label.label = @"Post #$(post.id)";
            rating_value.label = post.display_rating;
            score_value.label = @"$(post.score)";
            dims_value.label = @"$(post.image_width) × $(post.image_height)";
            file_size_value.label = post.file_size_display;
            source_value.label = post.source != "" ? post.source : "(none)";
            pixiv_value.label = post.pixiv_id >= 0 ? @"$(post.pixiv_id)" : "(none)";

            // Clear old tags
            while (true) {
                var child = tags_container.get_first_child();
                if (child == null) break;
                tags_container.remove(child);
            }

            // Re-add header after clear
            var tags_header = new Gtk.Label("Tags");
            tags_header.add_css_class("detail-id");
            tags_header.halign = Gtk.Align.START;
            tags_container.append(tags_header);

            add_tag_section("General", post.tag_string_general, "general");
            add_tag_section("Artist", post.tag_string_artist, "artist");
            add_tag_section("Character", post.tag_string_character, "character");
            add_tag_section("Copyright", post.tag_string_copyright, "copyright");
            add_tag_section("Meta", post.tag_string_meta, "meta");

            load_large_image.begin(api);
        }

        private void add_tag_section(string section_name, string tag_string, string css_class) {
            if (tag_string.strip() == "") return;

            var tags = tag_string.split(" ");
            var section_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            section_box.margin_start = 4;

            var section_lbl = new Gtk.Label(@"$(section_name):");
            section_lbl.add_css_class("tag-section-label");
            section_lbl.halign = Gtk.Align.START;
            section_box.append(section_lbl);

            var tag_flow = new Gtk.FlowBox();
            tag_flow.selection_mode = Gtk.SelectionMode.NONE;
            tag_flow.column_spacing = 6;
            tag_flow.row_spacing = 6;
            tag_flow.homogeneous = false;
            tag_flow.max_children_per_line = 1000;

            foreach (var tag in tags) {
                tag = tag.strip();
                if (tag == "") continue;

                var btn = new Gtk.Button.with_label(tag.replace("_", " "));
                btn.add_css_class("tag-button");
                btn.add_css_class(css_class);
                btn.tooltip_text = @"Search for '$(tag)'";
                btn.clicked.connect(() => {
                    tag_clicked(tag);
                });
                tag_flow.append(btn);
            }

            section_box.append(tag_flow);
            tags_container.append(section_box);
        }

        private async void load_large_image(Api api) {
            spinner.visible = true;
            spinner.start();
            image_widget.set_from_paintable(null);

            try {
                var url = post.large_url;
                if (url == "") return;

                var raw_bytes = yield api.download_bytes(url);
                var bytes = new GLib.Bytes(raw_bytes);
                var texture = Gdk.Texture.from_bytes(bytes);
                image_widget.set_from_paintable(texture);
            } catch (Error e) {
                warning("Failed to load image for post %lld: %s", post.id, e.message);
            }

            spinner.stop();
            spinner.visible = false;
        }

        private void on_open_browser() {
            if (post == null) return;
            try {
                var launcher = new Gtk.UriLauncher(post.page_url);
                launcher.launch.begin(this.get_root() as Gtk.Window, null);
            } catch (Error e) {
                warning("Failed to open URI: %s", e.message);
            }
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
                    warning("File dialog error: %s", e.message);
                }
            });
        }

        private async void download_original(string path) {
            if (current_api == null) return;
            try {
                var url = post.original_url;
                if (url == "") throw new IOError.NOT_FOUND("No URL");

                yield current_api.download_to_file(url, path);
                warning("Downloaded to: %s", path);
            } catch (Error e) {
                warning("Download failed for post %lld: %s", post.id, e.message);
            }
        }
    }
}
