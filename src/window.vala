namespace Danbooru {
    public class MainWindow : Adw.ApplicationWindow {
        private Api api;

        // Search
        private Gtk.SearchEntry search_entry;
        private Gtk.Popover? suggestion_popover;
        private Gtk.ListBox suggestion_list;
        private uint debounce_timer_id = 0;
        private int autocomplete_gen = 0;
        private Gtk.Switch show_explicit_switch;
        private Gtk.SpinButton limit_spin;
        private Gtk.DropDown size_dropdown;
        private Gtk.DropDown sort_dropdown;

        // Navigation
        private Gtk.Stack main_stack;
        private Gtk.Box search_toolbar;
        private Gtk.ActionBar bottom_bar;
        private Gtk.Box grid_page;
        private PostDetailView detail_view;

        // Grid
        private Gtk.FlowBox flowbox;
        private Gtk.ScrolledWindow grid_scroll;
        private Adw.StatusPage status_page;
        private Gtk.Spinner grid_spinner;

        // Continuous scroll
        private int current_page = 1;
        private string current_tags = "";
        private bool loading_more = false;
        private bool has_more = true;
        private Gtk.Spinner load_more_spinner;
        private int search_gen = 0;
        private PreviewSize preview_size = PreviewSize.MEDIUM;

        // Selection
        private List<Post> selected_posts = new GLib.List<Post>();
        private Gtk.Button download_btn;
        private Gtk.Button select_all_btn;
        private Gtk.Label selection_label;
        private bool select_all_mode = false;
        private int select_all_pages_loaded = 0;
        private const int MAX_SELECT_ALL_PAGES = 25;

        public MainWindow(Gtk.Application app) {
            Object(application: app);
        }

        construct {
            this.default_width = 1200;
            this.default_height = 850;
            this.title = "Danboruthingi";

            api = new Api();

            build_ui();
            setup_signals();
            connect_scroll_detection();

            start_fresh_search();
        }

        // ───────────── Build UI ─────────────

        private void build_ui() {
            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            var header = new Adw.HeaderBar();
            header.show_title = true;
            header.title_widget = new Adw.WindowTitle("Danboruthingi", "Danbooru browser");

            var explicit_control = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            var explicit_label = new Gtk.Label("Explicit");
            show_explicit_switch = new Gtk.Switch();
            show_explicit_switch.valign = Gtk.Align.CENTER;
            show_explicit_switch.tooltip_text = "Include explicit-rated posts in searches without a rating tag";
            explicit_control.append(explicit_label);
            explicit_control.append(show_explicit_switch);
            header.pack_end(explicit_control);

            vbox.append(header);

            // Search toolbar
            var search_clamp = new Adw.Clamp();
            search_clamp.maximum_size = 1240;
            search_clamp.tightening_threshold = 800;
            search_toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            search_toolbar.margin_start = 12;
            search_toolbar.margin_end = 12;
            search_toolbar.margin_top = 8;
            search_toolbar.margin_bottom = 8;

            search_entry = new Gtk.SearchEntry();
            search_entry.hexpand = true;
            search_entry.placeholder_text = "Search tags, for example: cat rating:s";

            var search_btn = new Gtk.Button.from_icon_name("edit-find-symbolic");
            search_btn.add_css_class("suggested-action");
            search_btn.tooltip_text = "Search";
            search_btn.clicked.connect(on_search_clicked);

            var limit_label = new Gtk.Label("Results");
            limit_label.add_css_class("dim-label");

            limit_spin = new Gtk.SpinButton.with_range(10, 100, 10);
            limit_spin.value = Config.DEFAULT_LIMIT;
            limit_spin.valign = Gtk.Align.CENTER;

            // Preview size dropdown
            var size_label = new Gtk.Label("Size");
            size_label.add_css_class("dim-label");
            var size_model = new Gtk.StringList(new string[] { "Small", "Medium", "Large" });
            size_dropdown = new Gtk.DropDown(size_model, null);
            size_dropdown.selected = 1;
            size_dropdown.tooltip_text = "Thumbnail preview size";
            size_dropdown.valign = Gtk.Align.CENTER;

            // Sort dropdown
            var sort_label = new Gtk.Label("Sort");
            sort_label.add_css_class("dim-label");
            var sort_model = new Gtk.StringList(new string[] {
                "Default",
                "Score",
                "Favorites",
                "Rank",
                "Newest",
                "Random"
            });
            sort_dropdown = new Gtk.DropDown(sort_model, null);
            sort_dropdown.selected = 0;
            sort_dropdown.tooltip_text = "Sort results by";
            sort_dropdown.valign = Gtk.Align.CENTER;

            search_toolbar.append(search_entry);
            search_toolbar.append(search_btn);
            search_toolbar.append(limit_label);
            search_toolbar.append(limit_spin);
            search_toolbar.append(size_label);
            search_toolbar.append(size_dropdown);
            search_toolbar.append(sort_label);
            search_toolbar.append(sort_dropdown);
            search_clamp.child = search_toolbar;
            vbox.append(search_clamp);

            // Main content stack
            main_stack = new Gtk.Stack();
            main_stack.vexpand = true;
            main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            // -- Grid page --
            grid_page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            status_page = new Adw.StatusPage();
            status_page.title = "Danboruthingi";
            status_page.description = "Enter tags above to browse Danbooru";
            status_page.icon_name = "edit-find-symbolic";
            status_page.vexpand = true;

            grid_scroll = new Gtk.ScrolledWindow();
            grid_scroll.vexpand = true;
            grid_scroll.visible = false;

            flowbox = new Gtk.FlowBox();
            flowbox.max_children_per_line = Config.flowbox_max_children_for_size(preview_size);
            flowbox.min_children_per_line = 2;
            flowbox.selection_mode = Gtk.SelectionMode.NONE;
            flowbox.column_spacing = 12;
            flowbox.row_spacing = 12;
            flowbox.homogeneous = false;

            var grid_clamp = new Adw.Clamp();
            grid_clamp.maximum_size = 1240;
            grid_clamp.tightening_threshold = 800;
            grid_clamp.margin_start = 12;
            grid_clamp.margin_end = 12;
            grid_clamp.margin_top = 12;
            grid_clamp.margin_bottom = 12;
            grid_clamp.child = flowbox;
            grid_scroll.child = grid_clamp;

            // Bottom loading spinner (below the scrolled grid)
            load_more_spinner = new Gtk.Spinner();
            load_more_spinner.halign = Gtk.Align.CENTER;
            load_more_spinner.margin_top = 12;
            load_more_spinner.margin_bottom = 16;
            load_more_spinner.visible = false;

            grid_page.append(status_page);
            grid_page.append(grid_scroll);
            grid_page.append(load_more_spinner);

            // Initial-load spinner overlay
            var grid_overlay = new Gtk.Overlay();
            grid_overlay.child = grid_page;

            grid_spinner = new Gtk.Spinner();
            grid_spinner.halign = Gtk.Align.CENTER;
            grid_spinner.valign = Gtk.Align.CENTER;
            grid_spinner.visible = false;
            grid_overlay.add_overlay(grid_spinner);

            main_stack.add_named(grid_overlay, "grid");

            // -- Detail page --
            detail_view = new PostDetailView();
            detail_view.back.connect(on_back_to_grid);
            detail_view.tag_clicked.connect(on_tag_clicked_from_detail);
            main_stack.add_named(detail_view, "detail");

            vbox.append(main_stack);

            bottom_bar = new Gtk.ActionBar();

            selection_label = new Gtk.Label("0 selected");
            selection_label.add_css_class("meta-label");

            select_all_btn = new Gtk.Button.with_label("Select All");
            select_all_btn.tooltip_text = "Select every result for the current search";
            select_all_btn.visible = false;
            select_all_btn.clicked.connect(on_select_all);

            download_btn = new Gtk.Button.with_label("Download");
            download_btn.add_css_class("suggested-action");
            download_btn.tooltip_text = "Download the highest quality available for selected posts";
            download_btn.sensitive = false;
            download_btn.clicked.connect(on_download_selected);

            var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
            refresh_btn.tooltip_text = "Refresh";
            refresh_btn.clicked.connect(on_refresh);

            bottom_bar.pack_start(selection_label);
            bottom_bar.pack_start(select_all_btn);
            bottom_bar.pack_start(download_btn);
            bottom_bar.pack_end(refresh_btn);

            vbox.append(bottom_bar);
            this.content = vbox;

            // Enter key triggers search
            search_entry.activate.connect(on_search_clicked);
        }

        // ───────────── Navigation ─────────────

        private void on_back_to_grid() {
            main_stack.visible_child_name = "grid";
            search_toolbar.visible = true;
            bottom_bar.visible = true;
        }

        private void on_tag_clicked_from_detail(string tag) {
            search_entry.text = tag;
            on_back_to_grid();
            start_fresh_search();
        }

        // ───────────── Infinite scroll ─────────────

        private void connect_scroll_detection() {
            grid_scroll.vadjustment.value_changed.connect(() => {
                if (loading_more || !has_more || select_all_mode) return;

                var adj = grid_scroll.vadjustment;
                double remaining = adj.upper - adj.page_size - adj.value;

                if (remaining < 500.0) {
                    load_more_posts();
                }
            });
        }

        private void load_more_posts() {
            if (loading_more || !has_more) return;

            loading_more = true;
            current_page++;

            load_more_spinner.visible = true;
            load_more_spinner.start();

            search_posts.begin(current_tags, current_page);
        }

        // ───────────── Search ─────────────

        private void setup_signals() {
            search_entry.changed.connect(() => {
                autocomplete_gen++;
                if (debounce_timer_id > 0) {
                    Source.remove(debounce_timer_id);
                }
                int captured_gen = autocomplete_gen;
                debounce_timer_id = Timeout.add(300, () => {
                    debounce_timer_id = 0;
                    do_autocomplete.begin(captured_gen);
                    return false;
                });
            });

            show_explicit_switch.notify["active"].connect(() => {
                start_fresh_search();
            });

            size_dropdown.notify["selected"].connect(() => {
                var new_size = (PreviewSize)size_dropdown.selected;
                if (new_size != preview_size) {
                    preview_size = new_size;
                    update_grid_preview_size();
                }
            });

            sort_dropdown.notify["selected"].connect(() => {
                start_fresh_search();
            });
        }

        private void on_search_clicked() {
            start_fresh_search(build_tag_query());
        }

        private void on_refresh() {
            start_fresh_search(current_tags);
        }

        private void start_fresh_search(string? explicit_tags = null) {
            search_gen++;
            string tags;
            if (explicit_tags != null) {
                tags = explicit_tags;
            } else {
                tags = build_tag_query();
            }
            current_page = 1;
            has_more = true;
            select_all_mode = false;
            select_all_pages_loaded = 0;
            clear_flowbox();
            {
                while (selected_posts.length() > 0) {
                    selected_posts.remove(selected_posts.nth_data(0));
                }
            }
            update_selection_ui();
            select_all_btn.visible = false;
            search(tags);
        }

        private string build_tag_query() {
            string[] tag_parts = {};

            var text = search_entry.text.strip();
            if (text != "") {
                tag_parts += text;
            }

            if (!show_explicit_switch.active && !text.down().contains("rating:")) {
                tag_parts += "-rating:e";
            }

            var sort_tag = get_sort_tag();
            if (sort_tag != "") {
                tag_parts += sort_tag;
            }

            return string.joinv(" ", tag_parts);
        }

        private string get_sort_tag() {
            switch (sort_dropdown.selected) {
                case 1: return "order:score";
                case 2: return "order:favcount";
                case 3: return "order:rank";
                case 4: return "order:date";
                case 5: return "order:random";
                default: return "";
            }
        }

        private void search(string tags) {
            current_tags = tags;
            status_page.visible = false;
            grid_scroll.visible = true;
            grid_spinner.visible = true;
            grid_spinner.start();
            load_more_spinner.visible = false;

            search_posts.begin(tags, current_page);
        }

        private async void search_posts(string tags, int page) {
            int captured_gen = search_gen;
            try {
                var limit = (int)limit_spin.value;
                var posts = yield api.search_posts(tags, page, limit);

                Idle.add(() => {
                    // Discard if a new search superseded this one
                    if (captured_gen != search_gen) return false;

                    populate_grid(posts);
                    grid_spinner.stop();
                    grid_spinner.visible = false;
                    loading_more = false;
                    load_more_spinner.stop();
                    load_more_spinner.visible = false;

                    has_more = posts.length() >= limit;
                    select_all_btn.visible = search_entry.text.strip() != "" &&
                        flowbox.get_child_at_index(0) != null;

                    if (select_all_mode) {
                        select_all_pages_loaded++;
                        if (has_more && select_all_pages_loaded < MAX_SELECT_ALL_PAGES) {
                            // Keep loading pages and auto-selecting new items
                            Timeout.add(50, () => {
                                if (captured_gen == search_gen && select_all_mode) {
                                    load_more_posts();
                                }
                                return false;
                            });
                        } else {
                            if (select_all_pages_loaded >= MAX_SELECT_ALL_PAGES) {
                                warning("Select All stopped at %d pages to avoid excessive requests", MAX_SELECT_ALL_PAGES);
                            }
                            stop_select_all_mode();
                        }
                    }

                    // Only show empty state on the very first page
                    if (page == 1 && posts.length() == 0) {
                        grid_scroll.visible = false;
                        status_page.visible = true;
                        status_page.title = "No Results";
                        status_page.description = current_tags != ""
                            ? @"No posts found for \"$(current_tags)\""
                            : "Enter tags to search";
                        status_page.icon_name = "edit-find-symbolic";
                    }

                    return false;
                });

            } catch (Error e) {
                var err_msg = e.message;
                Idle.add(() => {
                    // Discard if a new search superseded this one
                    if (captured_gen != search_gen) return false;

                    loading_more = false;
                    load_more_spinner.stop();
                    load_more_spinner.visible = false;
                    grid_spinner.stop();
                    grid_spinner.visible = false;

                    if (select_all_mode) {
                        stop_select_all_mode();
                    }

                    if (page > 1) {
                        warning("Failed to load page %d: %s", page, err_msg);
                    } else {
                        grid_scroll.visible = false;
                        status_page.visible = true;
                        status_page.title = "Search Failed";
                        status_page.description = err_msg;
                        status_page.icon_name = "dialog-error-symbolic";
                    }
                    return false;
                });
            }
        }

        // ───────────── Grid ─────────────

        private void populate_grid(List<Post> posts) {
            foreach (var post in posts) {
                var thumb = new ThumbnailWidget(post, preview_size);
                thumb.clicked.connect((p) => show_detail(p));
                thumb.selection_toggled.connect((p, sel) => {
                    on_selection_changed(p, sel);
                });
                flowbox.append(thumb);
                if (select_all_mode) {
                    thumb.set_selected(true);
                }
                thumb.load_thumbnail.begin(api);
            }
        }

        private void update_grid_preview_size() {
            flowbox.max_children_per_line = Config.flowbox_max_children_for_size(preview_size);
            int index = 0;
            while (true) {
                var child = flowbox.get_child_at_index(index++);
                if (child == null) break;
                var thumbnail = child.get_child() as ThumbnailWidget;
                if (thumbnail != null) {
                    thumbnail.set_preview_size(preview_size);
                }
            }
        }

        private void clear_flowbox() {
            while (true) {
                var child = flowbox.get_child_at_index(0);
                if (child == null) break;
                flowbox.remove(child);
            }
        }

        // ───────────── Selection ─────────────

        private void on_selection_changed(Post post, bool selected) {
            if (selected) {
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
            if (select_all_btn != null) {
                select_all_btn.sensitive = count < loaded_thumbnail_count() || has_more;
            }
        }

        private int loaded_thumbnail_count() {
            int count = 0;
            while (flowbox.get_child_at_index(count) != null) count++;
            return count;
        }

        private void on_select_all() {
            if (select_all_mode) {
                stop_select_all_mode();
                return;
            }

            select_all_mode = true;
            select_all_pages_loaded = 0;
            select_all_btn.label = "Stop";
            select_all_btn.tooltip_text = "Stop selecting all results";

            // Select all currently loaded thumbnails
            int index = 0;
            while (true) {
                var child = flowbox.get_child_at_index(index++);
                if (child == null) break;

                var thumbnail = child.get_child() as ThumbnailWidget;
                if (thumbnail != null) thumbnail.set_selected(true);
            }

            // If more pages exist, start loading them (auto-selected in populate_grid)
            if (has_more) {
                load_more_posts();
            } else {
                stop_select_all_mode();
            }
        }

        private void stop_select_all_mode() {
            select_all_mode = false;
            select_all_btn.label = "Select All";
            select_all_btn.tooltip_text = "Select every result for the current search";
        }

        // ───────────── Detail ─────────────

        private void show_detail(Post post) {
            search_toolbar.visible = false;
            bottom_bar.visible = false;
            detail_view.display_post(post, api);
            main_stack.visible_child_name = "detail";
        }

        // ───────────── Batch Download ─────────────

        private void on_download_selected() {
            if (selected_posts.length() == 0) return;

            Post[] posts_arr = {};
            foreach (var p in selected_posts) posts_arr += p;

            var dialog = new DownloadDialog(posts_arr);
            dialog.transient_for = this;
            dialog.present();
        }

        // ───────────── Autocomplete ─────────────

        private async void do_autocomplete(int captured_gen) {
            var text = search_entry.text;
            if (text.length < 2) {
                hide_suggestions();
                return;
            }

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
                    if (captured_gen != autocomplete_gen) return false;
                    if (suggestions.length() > 0) {
                        show_suggestions(suggestions, query);
                    } else {
                        hide_suggestions();
                    }
                    return false;
                });

            } catch (Error e) {
                // Silently fail
            }
        }

        private void show_suggestions(List<TagSuggestion> suggestions, string query) {
            if (suggestion_popover == null) {
                suggestion_popover = new Gtk.Popover();
                suggestion_popover.has_arrow = false;
                suggestion_popover.position = Gtk.PositionType.BOTTOM;
                suggestion_popover.autohide = true;
                suggestion_popover.can_focus = false;
                suggestion_popover.focusable = false;

                suggestion_list = new Gtk.ListBox();
                suggestion_list.add_css_class("boxed-list");
                suggestion_list.can_focus = false;
                suggestion_list.focusable = false;
                suggestion_list.selection_mode = Gtk.SelectionMode.NONE;
                suggestion_popover.child = suggestion_list;

                suggestion_list.row_activated.connect((row) => {
                    var box = row.get_child() as Gtk.Box;
                    if (box != null) {
                        var name_label = box.get_first_child() as Gtk.Label;
                        if (name_label != null) {
                            apply_suggestion(name_label.label);
                        }
                    }
                });
            }

            while (true) {
                var row = suggestion_list.get_row_at_index(0);
                if (row == null) break;
                suggestion_list.remove(row);
            }

            var cat_names = new string[] { "General", "Artist", "Character", "Copyright", "Meta" };

            foreach (var sug in suggestions) {
                var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
                box.margin_start = 8;
                box.margin_end = 8;
                box.margin_top = 4;
                box.margin_bottom = 4;
                box.can_focus = false;
                box.focusable = false;

                var name_label = new Gtk.Label(sug.name);
                name_label.halign = Gtk.Align.START;
                name_label.hexpand = true;
                name_label.ellipsize = Pango.EllipsizeMode.END;
                name_label.add_css_class("suggestion-name");
                name_label.can_focus = false;
                name_label.focusable = false;

                var count_label = new Gtk.Label(@"$(sug.post_count)");
                count_label.add_css_class("suggestion-count");
                count_label.can_focus = false;
                count_label.focusable = false;

                var cat_label = new Gtk.Label(cat_names[sug.category.clamp(0, 4)]);
                cat_label.add_css_class("suggestion-cat");
                cat_label.can_focus = false;
                cat_label.focusable = false;

                box.append(name_label);
                box.append(count_label);
                box.append(cat_label);

                var row = new Gtk.ListBoxRow();
                row.child = box;
                row.can_focus = false;
                row.focusable = false;
                row.selectable = false;
                suggestion_list.append(row);
            }

            if (suggestion_popover.get_parent() == null) {
                suggestion_popover.set_parent(search_entry);
            }
            suggestion_popover.popup();
            // Do not steal focus from the search entry; user should keep typing.
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
            // Keep focus on the search entry so typing can continue.
            search_entry.grab_focus();
        }
    }
}
