namespace Danbooru {
    public class DownloadDialog : Gtk.Window {
        private Gtk.ListBox file_list;
        private Gtk.Label status_label;
        private Gtk.ProgressBar progress_bar;
        private Gtk.Button cancel_button;
        private Gtk.Button start_button;
        private Gtk.Button close_button;
        private Gtk.Box button_box;
        private Gtk.Label count_label;
        private Gtk.Entry dir_entry;
        private Gtk.Button browse_button;

        private Post[] posts;
        private Api api;
        private Cancellable cancellable;
        private bool running = false;
        private int completed = 0;
        private int failed = 0;
        private int total = 0;

        public DownloadDialog(Post[] posts) {
            Object(
                title: "Batch Download",
                modal: true,
                default_width: 600,
                default_height: 400,
                transient_for: null
            );
            this.posts = posts;
            this.api = new Api();
            this.cancellable = new Cancellable();
        }

        construct {
            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            vbox.margin_start = 12;
            vbox.margin_end = 12;
            vbox.margin_top = 12;
            vbox.margin_bottom = 12;

            // Header
            count_label = new Gtk.Label(@"Selected $(posts.length) posts for download");
            count_label.add_css_class("heading");
            count_label.halign = Gtk.Align.START;
            vbox.append(count_label);

            // Directory selection
            var dir_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            var dir_label = new Gtk.Label("Save to:");
            dir_entry = new Gtk.Entry();
            dir_entry.hexpand = true;

            var pictures = Environment.get_user_special_dir(GLib.UserDirectory.PICTURES);
            dir_entry.text = pictures ?? Environment.get_home_dir();

            browse_button = new Gtk.Button.with_label("Browse...");
            browse_button.clicked.connect(on_browse);
            dir_box.append(dir_label);
            dir_box.append(dir_entry);
            dir_box.append(browse_button);
            vbox.append(dir_box);

            // File list
            var scrolled = new Gtk.ScrolledWindow();
            scrolled.vexpand = true;

            file_list = new Gtk.ListBox();
            file_list.add_css_class("boxed-list");

            foreach (var post in posts) {
                var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
                row.margin_start = 6;
                row.margin_end = 6;
                row.margin_top = 3;
                row.margin_bottom = 3;

                var icon = new Gtk.Image.from_icon_name("image-x-generic-symbolic");
                icon.pixel_size = 24;

                var info = new Gtk.Label(@"#$(post.id) — $(post.tag_string_general != "" ? post.tag_string_general.split(" ")[0] : "untitled").$(post.file_ext)");
                info.hexpand = true;
                info.halign = Gtk.Align.START;
                info.ellipsize = Pango.EllipsizeMode.END;

                var status_icon = new Gtk.Image.from_icon_name("emblem-important-symbolic");
                status_icon.visible = false;

                row.append(icon);
                row.append(info);
                row.append(status_icon);

                row.set_data<Gtk.Image>("status-icon", status_icon);

                file_list.append(row);
            }

            scrolled.child = file_list;
            vbox.append(scrolled);

            // Progress
            progress_bar = new Gtk.ProgressBar();
            progress_bar.visible = false;
            vbox.append(progress_bar);

            status_label = new Gtk.Label("");
            status_label.halign = Gtk.Align.START;
            vbox.append(status_label);

            // Buttons
            button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            button_box.halign = Gtk.Align.END;

            cancel_button = new Gtk.Button.with_label("Cancel");
            cancel_button.clicked.connect(() => {
                if (running) {
                    cancellable.cancel();
                } else {
                    close();
                }
            });

            start_button = new Gtk.Button.with_label("Start Download");
            start_button.add_css_class("suggested-action");

            close_button = new Gtk.Button.with_label("Close");
            close_button.visible = false;
            close_button.clicked.connect(() => close());

            start_button.clicked.connect(on_start_download);

            button_box.append(cancel_button);
            button_box.append(start_button);
            button_box.append(close_button);
            vbox.append(button_box);

            this.child = vbox;
        }

        private void on_browse() {
            var dialog = new Gtk.FileDialog();
            dialog.title = "Select Download Directory";
            dialog.initial_folder = GLib.File.new_for_path(dir_entry.text);

            dialog.select_folder.begin((Gtk.Window)this, null, (obj, res) => {
                try {
                    var folder = dialog.select_folder.end(res);
                    if (folder != null) {
                        dir_entry.text = folder.get_path();
                    }
                } catch (Error e) {
                    // User cancelled
                }
            });
        }

        private void on_start_download() {
            running = true;
            start_button.visible = false;
            cancel_button.label = "Cancel";
            progress_bar.visible = true;
            progress_bar.fraction = 0.0;
            total = posts.length;
            completed = 0;
            failed = 0;

            download_next.begin();
        }

        private async void download_next() {
            if (cancellable.is_cancelled()) {
                finish("Cancelled");
                return;
            }

            int current_idx = completed + failed;
            if (current_idx >= total) {
                finish(@"Completed: $(completed) downloaded, $(failed) failed");
                return;
            }

            var post = posts[current_idx];

            status_label.label = @"Downloading #$(post.id) ($(current_idx + 1)/$(total))...";
            progress_bar.fraction = (double)(completed + failed) / total;

            // Update the row
            var row = file_list.get_row_at_index(current_idx);
            if (row != null) {
                var icon = row.get_data<Gtk.Image>("status-icon");
                if (icon != null) {
                    icon.set_from_icon_name("emblem-synchronizing-symbolic");
                    icon.visible = true;
                }
            }

            try {
                var url = post.original_url;
                if (url == "") throw new IOError.NOT_FOUND("No URL for post");

                var dest_path = GLib.Path.build_filename(dir_entry.text, @"$(post.id)_$(post.md5).$(post.file_ext)");
                yield api.download_to_file(url, dest_path);
                completed++;

                if (row != null) {
                    var icon = row.get_data<Gtk.Image>("status-icon");
                    if (icon != null) {
                        icon.set_from_icon_name("emblem-ok-symbolic");
                        icon.visible = true;
                    }
                }

            } catch (Error e) {
                warning("Download failed for post %lld: %s", post.id, e.message);
                failed++;

                if (row != null) {
                    var icon = row.get_data<Gtk.Image>("status-icon");
                    if (icon != null) {
                        icon.set_from_icon_name("emblem-important-symbolic");
                        icon.visible = true;
                    }
                }
            }

            // Continue with next
            download_next.begin();
        }

        private void finish(string message) {
            running = false;
            status_label.label = message;
            progress_bar.fraction = 1.0;
            cancel_button.visible = false;
            close_button.visible = true;
            start_button.visible = false;
        }
    }
}
