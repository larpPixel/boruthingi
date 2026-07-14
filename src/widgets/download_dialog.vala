namespace Danbooru {
    public class DownloadDialog : Gtk.Window {
        private Gtk.ListBox file_list;
        private Gtk.Label status_label;
        private Gtk.ProgressBar progress_bar;
        private Gtk.Button cancel_button;
        private Gtk.Button start_button;
        private Gtk.Button close_button;
        private Gtk.Button retry_button;
        private Gtk.Box button_box;
        private Gtk.Label count_label;
        private Gtk.Entry dir_entry;
        private Gtk.Button browse_button;

        private Post[] posts;
        private Post[] current_batch;
        private Api api;
        private Cancellable cancellable;
        private bool running = false;
        private int completed = 0;
        private int failed = 0;
        private int total = 0;
        private List<int> failed_indices;

        public DownloadDialog(Post[] posts) {
            Object(
                title: "Batch Download",
                modal: true,
                default_width: 700,
                default_height: 500,
                transient_for: null
            );
            this.posts = posts;
            this.current_batch = posts;
            this.api = new Api();
            this.cancellable = new Cancellable();
            this.failed_indices = new GLib.List<int>();
        }

        construct {
            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            vbox.margin_start = 12;
            vbox.margin_end = 12;
            vbox.margin_top = 12;
            vbox.margin_bottom = 12;

            // Header
            count_label = new Gtk.Label(@"$(posts.length) selected posts - highest quality available");
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

            populate_file_list();

            scrolled.child = file_list;
            vbox.append(scrolled);

            // Progress
            progress_bar = new Gtk.ProgressBar();
            progress_bar.visible = false;
            vbox.append(progress_bar);

            status_label = new Gtk.Label("");
            status_label.halign = Gtk.Align.START;
            status_label.wrap = true;
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

            retry_button = new Gtk.Button.with_label("Retry Failed");
            retry_button.add_css_class("suggested-action");
            retry_button.visible = false;
            retry_button.clicked.connect(on_retry_failed);

            close_button = new Gtk.Button.with_label("Close");
            close_button.visible = false;
            close_button.clicked.connect(() => close());

            start_button.clicked.connect(on_start_download);

            button_box.append(cancel_button);
            button_box.append(retry_button);
            button_box.append(start_button);
            button_box.append(close_button);
            vbox.append(button_box);

            this.child = vbox;
        }

        private void populate_file_list() {
            while (true) {
                var row = file_list.get_row_at_index(0);
                if (row == null) break;
                file_list.remove(row);
            }

            foreach (var post in posts) {
                var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
                content.add_css_class("download-file-row");

                var icon = new Gtk.Image.from_icon_name("image-x-generic-symbolic");
                icon.pixel_size = 20;

                string first_tag = "untitled";
                if (post.tag_string_general != "") {
                    var parts = post.tag_string_general.split(" ");
                    if (parts.length > 0 && parts[0] != "") {
                        first_tag = parts[0];
                    }
                }

                var info = new Gtk.Label(@"#$(post.id) · $(first_tag).$(post.download_file_ext)");
                info.hexpand = true;
                info.halign = Gtk.Align.START;
                info.ellipsize = Pango.EllipsizeMode.END;

                var status_icon = new Gtk.Image.from_icon_name("emblem-important-symbolic");
                status_icon.add_css_class("download-status-icon");
                status_icon.visible = false;

                var status_text = new Gtk.Label("");
                status_text.halign = Gtk.Align.END;
                status_text.add_css_class("meta-label");
                status_text.ellipsize = Pango.EllipsizeMode.END;
                status_text.max_width_chars = 28;
                status_text.visible = false;

                content.append(icon);
                content.append(info);
                content.append(status_text);
                content.append(status_icon);

                // ListBox wraps children in a ListBoxRow — store data on the row we query later.
                var row = new Gtk.ListBoxRow();
                row.child = content;
                row.set_data<Gtk.Image>("status-icon", status_icon);
                row.set_data<Gtk.Label>("status-text", status_text);
                file_list.append(row);
            }
        }

        private int index_of_post(Post post) {
            for (int i = 0; i < posts.length; i++) {
                if (posts[i].id == post.id) return i;
            }
            return -1;
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
            retry_button.visible = false;
            cancel_button.label = "Cancel";
            progress_bar.visible = true;
            progress_bar.fraction = 0.0;
            total = current_batch.length;
            completed = 0;
            failed = 0;
            failed_indices = new GLib.List<int>();

            download_next.begin();
        }

        private void on_retry_failed() {
            if (failed_indices.length() == 0) return;

            Post[] retry_posts = {};
            foreach (int idx in failed_indices) {
                retry_posts += posts[idx];
            }

            // Reset status for the rows being retried
            foreach (int idx in failed_indices) {
                set_row_status(idx, "waiting", "");
            }

            current_batch = retry_posts;
            on_start_download();
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

            var post = current_batch[current_idx];
            int original_index = index_of_post(post);
            if (original_index < 0) original_index = current_idx;

            status_label.label = @"Downloading #$(post.id) ($(current_idx + 1)/$(total))...";
            progress_bar.fraction = (double)(completed + failed) / total;
            set_row_status(original_index, "downloading", "");

            string? error_message = null;
            try {
                var url = post.original_url;
                if (url == "") throw new IOError.NOT_FOUND("No URL for post");

                var dest_path = GLib.Path.build_filename(dir_entry.text, @"$(post.id)_$(post.md5).$(post.download_file_ext)");
                yield api.download_to_file(url, dest_path, cancellable);
                completed++;
                set_row_status(original_index, "completed", "");

            } catch (Error e) {
                warning("Download failed for post %lld: %s", post.id, e.message);
                error_message = e.message;
                failed++;
                failed_indices.append(original_index);
                set_row_status(original_index, "failed", error_message);
            }

            // Continue with next
            download_next.begin();
        }

        private void set_row_status(int index, string status, string message) {
            var row = file_list.get_row_at_index(index);
            if (row == null) return;

            var icon = row.get_data<Gtk.Image>("status-icon");
            var label = row.get_data<Gtk.Label>("status-text");

            if (icon != null) {
                icon.visible = true;
                switch (status) {
                    case "downloading":
                        icon.set_from_icon_name("emblem-synchronizing-symbolic");
                        break;
                    case "completed":
                        icon.set_from_icon_name("emblem-ok-symbolic");
                        break;
                    case "failed":
                        icon.set_from_icon_name("emblem-important-symbolic");
                        break;
                    case "waiting":
                    default:
                        icon.visible = false;
                        break;
                }
            }

            if (label != null) {
                if (status == "failed" && message != "") {
                    label.label = @"Failed: $(message)";
                    label.tooltip_text = message;
                    label.visible = true;
                } else if (status == "downloading") {
                    label.label = "Downloading...";
                    label.visible = true;
                } else {
                    label.label = "";
                    label.visible = false;
                }
            }
        }

        private void finish(string message) {
            running = false;
            status_label.label = message;
            progress_bar.fraction = 1.0;
            cancel_button.visible = false;
            close_button.visible = true;
            start_button.visible = false;
            retry_button.visible = failed > 0;
        }
    }
}
