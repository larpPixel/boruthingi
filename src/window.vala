namespace Danbooru {
    public class MainWindow : Gtk.ApplicationWindow {
        private Api api;

        // Search
        private Gtk.Entry search_entry;
        private Gtk.Popover? suggestion_popover;
        private Gtk.ListBox suggestion_list;
        private uint debounce_timer_id = 0;

        // Filters
        private Gtk.ToggleButton show_explicit_btn;
        private Gtk.SpinButton limit_spin;

        // Grid
        private Gtk.FlowBox flowbox;
        private Gtk.ScrolledWindow grid_scroll;
        private Gtk.Label empty_label;

        // Pagination
        private Gtk.Label page_label;
        private Gtk.Button prev_btn;
        private Gtk.Button next_btn;
        private int current_page = 1;
        private string current_tags = "";
        

        // Selection
        private List<Post> selected_posts;
        private Gtk.Button download_btn;
        private Gtk.Label selection_label;

        // Stack
        private Gtk.Stack main_stack;
        private PostDetailView detail_view;

        // State
        private Gtk.Spinner grid_spinner;
        private List<Post> current_posts;

        public MainWindow(Gtk.Application app) {
            Object(application: app);
        }

        construct {
            this.title = Config.APP_NAME;
            this.default_width = 1100;
            this.default_height = 800;

            api = new Api();
            selected_posts = new GLib.List<Post>();
            current_posts = new GLib.List<Post>();

            setup_ui();
            setup_signals();

            // Load initial content
            search("rating:s");
        }

        private void setup_ui() {
            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            // === Top toolbar ===
            var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            toolbar.margin_start = 8;
            toolbar.margin_end = 8;
            toolbar.margin_top = 8;
            toolbar.margin_bottom = 4;

            // Search entry
            search_entry = new Gtk.Entry();
            search_entry.hexpand = true;
            search_entry.placeholder_text = "Search tags (e.g. 'cat rating:s')...";
            search_entry.add_css_class("search-bar");
            search_entry.primary_icon_name = "edit-find-symbolic";
            search_entry.primary_icon_activatable = false;

            var search_btn = new Gtk.Button.with_label("Search");
            search_btn.add_css_class("suggested-action");
            search_btn.clicked.connect(on_search_clicked);

            toolbar.append(search_entry);
            toolbar.append(search_btn);

            // Rating filter
            var rating_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            rating_box.margin_start = 8;

            show_explicit_btn = new Gtk.ToggleButton.with_label("Show Explicit");
            show_explicit_btn.add_css_class("pill");
            show_explicit_btn.tooltip_text = "When off, only Safe content is shown";
            rating_box.append(show_explicit_btn);

            toolbar.append(rating_box);

            // Limit
            var limit_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            limit_box.margin_start = 8;

            var limit_label = new Gtk.Label("Limit:");
            limit_spin = new Gtk.SpinButton.with_range(10, 100, 10);
            limit_spin.value = Config.DEFAULT_LIMIT;
            limit_spin.valign = Gtk.Align.CENTER;
            limit_box.append(limit_label);
            limit_box.append(limit_spin);

            toolbar.append(limit_box);

            vbox.append(toolbar);

            // === Action bar (pagination + selection) ===
            var action_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            action_bar.margin_start = 8;
            action_bar.margin_end = 8;
            action_bar.margin_top = 4;
            action_bar.margin_bottom = 4;

            prev_btn = new Gtk.Button.with_label("◀ Previous");
            prev_btn.add_css_class("pill");
            prev_btn.sensitive = false;
            prev_btn.clicked.connect(on_prev_page);
            action_bar.append(prev_btn);

            page_label = new Gtk.Label("Page 1");
            page_label.add_css_class("pagination-label");
            action_bar.append(page_label);

            next_btn = new Gtk.Button.with_label("Next ▶");
            next_btn.add_css_class("pill");
            next_btn.sensitive = false;
            next_btn.clicked.connect(on_next_page);
            action_bar.append(next_btn);

            // Spacer
            var spacer = new Gtk.Label("");
            spacer.hexpand = true;
            action_bar.append(spacer);

            // Selection
            selection_label = new Gtk.Label("0 selected");
            selection_label.add_css_class("meta-label");
            action_bar.append(selection_label);

            download_btn = new Gtk.Button.with_label("Download Selected");
            download_btn.add_css_class("pill");
            download_btn.add_css_class("suggested-action");
            download_btn.sensitive = false;
            download_btn.clicked.connect(on_download_selected);
            action_bar.append(download_btn);

            var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
            refresh_btn.clicked.connect(on_search_clicked);
            action_bar.append(refresh_btn);

            vbox.append(action_bar);

            // === Main content (stack) ===
            main_stack = new Gtk.Stack();
            main_stack.vexpand = true;
            main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            // Grid view
            var grid_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            grid_scroll = new Gtk.ScrolledWindow();
            grid_scroll.vexpand = true;

            flowbox = new Gtk.FlowBox();
            flowbox.max_children_per_line = 8;
            flowbox.min_children_per_line = 2;
            flowbox.selection_mode = Gtk.SelectionMode.NONE;
            flowbox.column_spacing = 6;
            flowbox.row_spacing = 6;
            flowbox.homogeneous = false;

            grid_scroll.child = flowbox;
            grid_box.append(grid_scroll);

            // Spinner overlay for grid
            var grid_overlay = new Gtk.Overlay();
            grid_overlay.child = grid_box;

            grid_spinner = new Gtk.Spinner();
            grid_spinner.halign = Gtk.Align.CENTER;
            grid_spinner.valign = Gtk.Align.CENTER;
            grid_spinner.visible = false;
            grid_overlay.add_overlay(grid_spinner);

            main_stack.add_named(grid_overlay, "grid");

            // Detail view
            detail_view = new PostDetailView();
            detail_view.back.connect(() => main_stack.visible_child_name = "grid");
            detail_view.tag_clicked.connect((tag) => {
                search_entry.text = tag;
                main_stack.visible_child_name = "grid";
                search(tag);
            });
            main_stack.add_named(detail_view, "detail");

            vbox.append(main_stack);

            // === Status bar ===
            empty_label = new Gtk.Label("Enter tags to search");
            empty_label.add_css_class("empty-state");
            empty_label.halign = Gtk.Align.CENTER;
            empty_label.valign = Gtk.Align.CENTER;
            empty_label.vexpand = true;
            // GTK4 FlowBox doesn't have set_placeholder - empty state handled via spinner

            this.child = vbox;

            // Keyboard shortcut: Enter in search
            search_entry.activate.connect(on_search_clicked);
        }

        private void setup_signals() {
            // Tag autocomplete with debounce
            search_entry.changed.connect(() => {
                if (debounce_timer_id > 0) {
                    Source.remove(debounce_timer_id);
                }
                debounce_timer_id = Timeout.add(300, () => {
                    debounce_timer_id = 0;
                    do_autocomplete.begin();
                    return false;
                });
            });

            var focus_ctrl = new Gtk.EventControllerFocus();
            focus_ctrl.leave.connect(() => hide_suggestions());
            search_entry.add_controller(focus_ctrl);
        }

        private void on_search_clicked() {
            var tags = build_tag_query();
            current_page = 1;
            search(tags);
        }

        private string build_tag_query() {
            string[] tag_parts = {};

            var text = search_entry.text.strip();
            if (text != "") {
                tag_parts += text;
            }

            // Default safe-only when toggle is off AND user didn't specify a rating tag
            if (!show_explicit_btn.active && !text.down().contains("rating:")) {
                tag_parts += "rating:s";
            }

            return string.joinv(" ", tag_parts);
        }

        // unused — kept for interface compatibility

        // === Search ===
        private void search(string tags) {
            current_tags = tags;
            grid_spinner.visible = true;
            grid_spinner.start();

            // Clear current posts
            clear_flowbox();
            selected_posts = new GLib.List<Post>();
            update_selection_ui();

            search_posts.begin(tags, current_page);
        }

        private async void search_posts(string tags, int page) {
            try {
                var limit = (int)limit_spin.value;
                var posts = yield api.search_posts(tags, page, limit);

                current_posts = new GLib.List<Post>();
                foreach (var p in posts) current_posts.append(p);

                Idle.add(() => {
                    populate_grid(posts);
                    grid_spinner.stop();
                    grid_spinner.visible = false;

                    page_label.label = @"Page $(page)";
                    prev_btn.sensitive = page > 1;
                    next_btn.sensitive = posts.length() >= limit;

                    if (posts.length() == 0) {
                        empty_label.label = current_tags != "" ?
                            @"No results for '$(current_tags)'" :
                            "Enter tags to search";
                    }

                    return false;
                });

            } catch (Error e) {
                var err_msg = e.message;
                Idle.add(() => {
                    empty_label.label = @"Error: $(err_msg)";
                    grid_spinner.stop();
                    grid_spinner.visible = false;
                    return false;
                });
            }
        }

        private void populate_grid(List<Post> posts) {
            clear_flowbox();

            foreach (var post in posts) {
                var thumb = new ThumbnailWidget(post);
                thumb.clicked.connect((p) => show_detail(p));
                thumb.selection_toggled.connect((p, sel) => {
                    on_selection_changed(p, sel);
                });
                flowbox.append(thumb);
                thumb.load_thumbnail.begin(api);
            }
        }

        private void clear_flowbox() {
            while (true) {
                var child = flowbox.get_child_at_index(0);
                if (child == null) break;
                flowbox.remove(child);
            }
        }

        private void on_selection_changed(Post post, bool selected) {
            if (selected) {
                // Check if already in list
                bool found = false;
                foreach (var p in selected_posts) {
                    if (p.id == post.id) { found = true; break; }
                }
                if (!found) selected_posts.append(post);
            } else {
                Post? to_remove = null;
                foreach (var p in selected_posts) {
                    if (p.id == post.id) { to_remove = p; break; }
                }
                if (to_remove != null) selected_posts.remove(to_remove);
            }
            update_selection_ui();
        }

        private void update_selection_ui() {
            var count = selected_posts.length();
            selection_label.label = @"$(count) selected";
            download_btn.sensitive = count > 0;
        }

        // === Detail View ===
        private void show_detail(Post post) {
            detail_view.display_post(post, api);
            main_stack.visible_child_name = "detail";
        }

        // === Pagination ===
        private void on_prev_page() {
            if (current_page > 1) {
                current_page--;
                search(current_tags);
            }
        }

        private void on_next_page() {
            current_page++;
            search(current_tags);
        }

        // === Batch Download ===
        private void on_download_selected() {
            if (selected_posts.length() == 0) return;

            Post[] posts_arr = {};
            foreach (var p in selected_posts) posts_arr += p;

            var dialog = new DownloadDialog(posts_arr);
            dialog.transient_for = this;
            dialog.present();
        }

        // === Autocomplete ===
        private async void do_autocomplete() {
            var text = search_entry.text;
            if (text.length < 2) {
                hide_suggestions();
                return;
            }

            // Get last word for autocomplete
            var last_space = text.last_index_of(" ");
            string query;
            if (last_space >= 0) {
                query = text.substring(last_space + 1);
            } else {
                query = text;
            }

            if (query.length < 2) {
                hide_suggestions();
                return;
            }

            try {
                var suggestions = yield api.autocomplete_tags(query);

                Idle.add(() => {
                    if (suggestions.length() > 0) {
                        show_suggestions(suggestions, query);
                    } else {
                        hide_suggestions();
                    }
                    return false;
                });

            } catch (Error e) {
                // Silently fail on autocomplete errors
            }
        }

        private void show_suggestions(List<TagSuggestion> suggestions, string query) {
            if (suggestion_popover == null) {
                suggestion_popover = new Gtk.Popover();
                suggestion_popover.has_arrow = false;
                suggestion_popover.position = Gtk.PositionType.BOTTOM;
                suggestion_popover.autohide = true;

                suggestion_list = new Gtk.ListBox();
                suggestion_list.add_css_class("boxed-list");
                suggestion_popover.child = suggestion_list;

                suggestion_list.row_activated.connect((row) => {
                    var label = row.get_child() as Gtk.Label;
                    if (label != null) {
                        apply_suggestion(label.label);
                    }
                });
            }

            // Clear old items
            while (true) {
                var row = suggestion_list.get_row_at_index(0);
                if (row == null) break;
                suggestion_list.remove(row);
            }

            var cat_names = new string[] { "General", "Artist", "Character", "Copyright", "Meta" };

            foreach (var sug in suggestions) {
                var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
                box.margin_start = 6;
                box.margin_end = 6;
                box.margin_top = 2;
                box.margin_bottom = 2;

                var name_label = new Gtk.Label(sug.name);
                name_label.halign = Gtk.Align.START;
                name_label.hexpand = true;
                name_label.ellipsize = Pango.EllipsizeMode.END;

                var count_label = new Gtk.Label(@"$(sug.post_count)");
                count_label.add_css_class("badge");
                count_label.opacity = 0.6;

                var cat_label = new Gtk.Label(cat_names[sug.category.clamp(0, 4)]);
                cat_label.add_css_class("badge");

                box.append(name_label);
                box.append(count_label);
                box.append(cat_label);

                suggestion_list.append(box);
            }

            suggestion_popover.set_parent(search_entry);
            suggestion_popover.popup();
        }

        private void hide_suggestions() {
            if (suggestion_popover != null) {
                suggestion_popover.popdown();
            }
        }

        private void apply_suggestion(string tag) {
            var text = search_entry.text;
            var last_space = text.last_index_of(" ");
            string new_text;
            if (last_space >= 0) {
                new_text = text.substring(0, last_space + 1) + tag;
            } else {
                new_text = tag;
            }
            search_entry.text = new_text + " ";
            search_entry.set_position(-1);
            hide_suggestions();
        }
    }
}
