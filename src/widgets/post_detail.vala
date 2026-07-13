namespace Danbooru {
    public class PostDetailView : Gtk.Box {
        public signal void back();
        public signal void tag_clicked(string tag);

        public Post post { get; set; }

        private Gtk.Image image_widget;
        private Gtk.Label id_label;
        private Gtk.FlowBox tag_flow;
        private Gtk.ScrolledWindow tag_scroll;
        private Gtk.Box tag_sections_box;
        private Gtk.Button open_button;
        private Gtk.Button download_button;
        private Gtk.Spinner spinner;

        public PostDetailView() {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        }

        construct {
            // Header bar
            var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            header.margin_start = 8;
            header.margin_end = 8;
            header.margin_top = 8;
            header.margin_bottom = 8;

            var back_btn = new Gtk.Button.from_icon_name("go-previous-symbolic");
            back_btn.tooltip_text = "Back to grid";
            back_btn.clicked.connect(() => back());
            header.append(back_btn);

            id_label = new Gtk.Label("");
            id_label.add_css_class("heading");
            id_label.hexpand = true;
            id_label.halign = Gtk.Align.START;
            header.append(id_label);

            open_button = new Gtk.Button.with_label("Open in Browser");
            open_button.add_css_class("pill");
            open_button.clicked.connect(on_open_browser);
            header.append(open_button);

            download_button = new Gtk.Button.with_label("Download Original");
            download_button.add_css_class("pill");
            download_button.add_css_class("suggested-action");
            download_button.clicked.connect(on_download_original);
            header.append(download_button);

            this.append(header);

            // Separator
            this.append(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));

            // Main content (scrollable)
            var main_scroll = new Gtk.ScrolledWindow();
            main_scroll.vexpand = true;
            main_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;

            var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            content.margin_start = 12;
            content.margin_end = 12;
            content.margin_top = 12;
            content.margin_bottom = 12;

            // Image area
            var image_frame = new Gtk.Frame(null);
            image_frame.add_css_class("image-frame");

            spinner = new Gtk.Spinner();
            spinner.start();

            image_widget = new Gtk.Image();
            image_widget.vexpand = false;
            image_widget.hexpand = true;

            var image_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            image_box.halign = Gtk.Align.CENTER;
            image_box.append(spinner);
            image_box.append(image_widget);
            image_frame.child = image_box;
            content.append(image_frame);

            // Metadata section
            var meta_grid = new Gtk.Grid();
            meta_grid.column_spacing = 16;
            meta_grid.row_spacing = 4;
            meta_grid.margin_top = 4;

            int row = 0;
            add_meta_row(meta_grid, ref row, "ID", null);
            add_meta_row(meta_grid, ref row, "Rating", null);
            add_meta_row(meta_grid, ref row, "Score", null);
            add_meta_row(meta_grid, ref row, "Dimensions", null);
            add_meta_row(meta_grid, ref row, "File Size", null);
            add_meta_row(meta_grid, ref row, "Source", null);
            add_meta_row(meta_grid, ref row, "Pixiv ID", null);

            // We'll update these labels via references later
            // For now, store the value labels to update
            content.append(meta_grid);

            // Tags section
            tag_sections_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            tag_sections_box.margin_top = 8;

            var tags_label = new Gtk.Label("Tags");
            tags_label.add_css_class("heading");
            tags_label.halign = Gtk.Align.START;
            tag_sections_box.append(tags_label);

            tag_scroll = new Gtk.ScrolledWindow();
            tag_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            tag_scroll.max_content_height = 300;

            tag_flow = new Gtk.FlowBox();
            tag_flow.max_children_per_line = 30;
            tag_flow.selection_mode = Gtk.SelectionMode.NONE;
            tag_flow.column_spacing = 4;
            tag_flow.row_spacing = 4;

            tag_scroll.child = tag_flow;
            tag_sections_box.append(tag_scroll);

            content.append(tag_sections_box);

            main_scroll.child = content;
            this.append(main_scroll);
        }

        private void add_meta_row(Gtk.Grid grid, ref int row, string label, string? value) {
            var lbl = new Gtk.Label(@"$(label):");
            lbl.halign = Gtk.Align.END;
            lbl.add_css_class("meta-label");
            lbl.hexpand = false;

            var val = new Gtk.Label(value ?? "...");
            val.halign = Gtk.Align.START;
            val.hexpand = true;
            val.selectable = true;
            val.add_css_class("meta-value");

            // Store as data so we can find it later
            val.set_data<string>("meta-key", label);

            grid.attach(lbl, 0, row, 1, 1);
            grid.attach(val, 1, row, 1, 1);
            row++;
        }

        private void set_meta(string key, string value) {
            // Walk the grid to find the value label for this key
            var parent = ((Gtk.Widget)this.get_last_child()).get_last_child() as Gtk.Grid;
            if (parent == null) return;

            // Find the grid - it should be the second-to-last child before tag_sections_box
            Gtk.Grid meta_grid = find_meta_grid();
            if (meta_grid == null) return;

            for (int i = 0; i < 7; i++) {
                var val = meta_grid.get_child_at(1, i) as Gtk.Label;
                if (val != null) {
                    string? stored_key = val.get_data<string>("meta-key");
                    if (stored_key == key) {
                        val.label = value;
                        return;
                    }
                }
            }
        }

        private Gtk.Grid? find_meta_grid() {
            var content = ((Gtk.Widget)this.get_last_child()) as Gtk.Box;
            if (content == null) return null;
            var children = content.observe_children();
            for (uint i = 0; i < children.get_n_items(); i++) {
                var child = children.get_item(i) as Gtk.Widget;
                if (child is Gtk.Grid) {
                    return child as Gtk.Grid;
                }
            }
            return null;
        }
        // find_tag_sections removed - not needed

        public void display_post(Post post, Api api) {
            this.post = post;

            id_label.label = @"Post #$(post.id)";
            set_meta("ID", @"$(post.id)");
            set_meta("Rating", post.display_rating);
            set_meta("Score", @"$(post.score)");
            set_meta("Dimensions", @"$(post.image_width) × $(post.image_height)");
            set_meta("File Size", post.file_size_display);
            set_meta("Source", post.source != "" ? post.source : "(none)");
            set_meta("Pixiv ID", post.pixiv_id >= 0 ? @"$(post.pixiv_id)" : "(none)");

            // Clear old tags
            while (true) {
                var child = tag_flow.get_child_at_index(0);
                if (child == null) break;
                tag_flow.remove(child);
            }

            // Add tag sections
            add_tag_section("General", post.tag_string_general);
            add_tag_section("Artist", post.tag_string_artist);
            add_tag_section("Character", post.tag_string_character);
            add_tag_section("Copyright", post.tag_string_copyright);
            add_tag_section("Meta", post.tag_string_meta);

            // Load large image
            load_large_image.begin(api);
        }

        private void add_tag_section(string section_name, string tag_string) {
            if (tag_string.strip() == "") return;

            var tags = tag_string.split(" ");
            var section_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            section_box.margin_start = 4;

            var section_lbl = new Gtk.Label(@"$(section_name):");
            section_lbl.add_css_class("tag-section-label");
            section_lbl.halign = Gtk.Align.START;
            section_box.append(section_lbl);

            foreach (var tag in tags) {
                tag = tag.strip();
                if (tag == "") continue;

                var btn = new Gtk.Button.with_label(tag.replace("_", " "));
                btn.add_css_class("tag-button");
                btn.add_css_class("tag-$(section_name.down())");
                btn.tooltip_text = @"Search for '$(tag)'";
                btn.clicked.connect(() => {
                    tag_clicked(tag);
                });
                section_box.append(btn);
            }

            tag_flow.append(section_box);
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
            file_chooser.title = "Save Original Image";
            file_chooser.initial_name = @"$(post.id)_$(post.md5).$(post.file_ext)";

            // Set initial folder to Pictures
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

        private async void download_original(string dest_path) {
            download_button.sensitive = false;
            download_button.label = "Downloading...";

            try {
                var url = post.original_url;
                if (url == "") return;

                var api = new Api();
                yield api.download_to_file(url, dest_path);

                download_button.label = "Downloaded!";
                // Reset after a delay
                Timeout.add_seconds(2, () => {
                    download_button.label = "Download Original";
                    download_button.sensitive = true;
                    return false;
                });
            } catch (Error e) {
                warning("Download failed: %s", e.message);
                download_button.label = "Download Failed";
                Timeout.add_seconds(3, () => {
                    download_button.label = "Download Original";
                    download_button.sensitive = true;
                    return false;
                });
            }
        }
    }
}
