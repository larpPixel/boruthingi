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
        private Gtk.DropDown limit_dropdown;
        private Gtk.DropDown size_dropdown;
        private Gtk.DropDown sort_dropdown;
        private static int[] LIMIT_VALUES = { 10, 20, 30, 40, 50, 60, 80, 100 };

        // Navigation
        private Gtk.Stack main_stack;
        private AppBar search_toolbar;
        private AppBar bottom_bar;
        private PostDetailView detail_view;

        // Grid
        private Gtk.Stack grid_stack;
        private Gtk.FlowBox flowbox;
        private Gtk.ScrolledWindow grid_scroll;
        private Adw.StatusPage status_page;
        private Gtk.Spinner grid_spinner;
        private Gtk.Spinner load_more_spinner;

        // Continuous scroll
        private int current_page = 1;
        private string current_tags = "";
        private bool loading_more = false;
        private bool has_more = true;
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
            var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            // ── Top bar ──
            // One control type for options (dropdowns) so heights match.
            // Labels live in tooltips — the selected value is the label.
            search_toolbar = new AppBar(false);

            search_entry = new Gtk.SearchEntry();
            search_entry.hexpand = true;
            search_entry.placeholder_text = "Search tags…";
            search_entry.add_css_class("bar-control");
            search_entry.valign = Gtk.Align.CENTER;
            search_entry.activate.connect(on_search_clicked);

            var search_btn = make_icon_btn("edit-find-symbolic", "Search");
            search_btn.add_css_class("suggested-action");
            search_btn.clicked.connect(on_search_clicked);

            search_toolbar.pack_start(search_entry);
            search_toolbar.pack_start(search_btn);

            size_dropdown = make_dropdown(
                new string[] { "Small", "Medium", "Large" },
                1,
                "Thumbnail size"
            );

            int default_limit_idx = 3; // 40
            for (int i = 0; i < LIMIT_VALUES.length; i++) {
                if (LIMIT_VALUES[i] == Config.DEFAULT_LIMIT) {
                    default_limit_idx = i;
                    break;
                }
            }
            string[] limit_labels = new string[LIMIT_VALUES.length];
            for (int i = 0; i < LIMIT_VALUES.length; i++) {
                limit_labels[i] = LIMIT_VALUES[i].to_string();
            }
            limit_dropdown = make_dropdown(limit_labels, default_limit_idx, "Results per page");

            sort_dropdown = make_dropdown(
                new string[] { "Default", "Score", "Favorites", "Rank", "Newest", "Random" },
                0,
                "Sort order"
            );

            show_explicit_switch = new Gtk.Switch();
            show_explicit_switch.valign = Gtk.Align.CENTER;
            show_explicit_switch.tooltip_text = "Include explicit posts when no rating tag is set";

            var explicit_label = new Gtk.Label("Explicit");
            explicit_label.add_css_class("bar-label");
            explicit_label.valign = Gtk.Align.CENTER;

            // Tight label+switch pair (only nested group in the bar).
            var explicit_pair = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            explicit_pair.valign = Gtk.Align.CENTER;
            explicit_pair.append(explicit_label);
            explicit_pair.append(show_explicit_switch);

            search_toolbar.pack_end(size_dropdown);
            search_toolbar.pack_end(limit_dropdown);
            search_toolbar.pack_end(sort_dropdown);
            search_toolbar.pack_end(AppBar.make_separator());
            search_toolbar.pack_end(explicit_pair);

            root.append(search_toolbar);

            // ── Main: grid | detail ──
            main_stack = new Gtk.Stack();
            main_stack.vexpand = true;
            main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            // Grid is one overlay: stack (empty | scroll) + spinners. No page box sandwich.
            var grid_overlay = new Gtk.Overlay();
            grid_overlay.vexpand = true;

            grid_stack = new Gtk.Stack();
            grid_stack.vexpand = true;
            grid_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            grid_stack.transition_duration = 120;

            status_page = new Adw.StatusPage();
            status_page.title = "Danboruthingi";
            status_page.description = "Enter tags above to browse Danbooru";
            status_page.icon_name = "edit-find-symbolic";
            grid_stack.add_named(status_page, "empty");

            grid_scroll = new Gtk.ScrolledWindow();
            grid_scroll.vexpand = true;
            grid_scroll.hexpand = true;
            grid_scroll.propagate_natural_height = false;

            flowbox = new Gtk.FlowBox();
            flowbox.add_css_class("post-grid");
            flowbox.max_children_per_line = Config.flowbox_max_children_for_size(preview_size);
            flowbox.min_children_per_line = 1;
            flowbox.selection_mode = Gtk.SelectionMode.NONE;
            flowbox.column_spacing = 8;
            flowbox.row_spacing = 8;
            flowbox.homogeneous = true;
            flowbox.valign = Gtk.Align.START;
            flowbox.halign = Gtk.Align.FILL;
            // Padding lives on the flow itself — no Clamp / wrapper margins.
            flowbox.margin_start = 8;
            flowbox.margin_end = 8;
            flowbox.margin_top = 8;
            flowbox.margin_bottom = 8;
            grid_scroll.child = flowbox;
            grid_stack.add_named(grid_scroll, "grid");

            grid_overlay.child = grid_stack;

            grid_spinner = new Gtk.Spinner();
            grid_spinner.halign = Gtk.Align.CENTER;
            grid_spinner.valign = Gtk.Align.CENTER;
            grid_spinner.width_request = 28;
            grid_spinner.height_request = 28;
            grid_spinner.visible = false;
            grid_overlay.add_overlay(grid_spinner);

            load_more_spinner = new Gtk.Spinner();
            load_more_spinner.halign = Gtk.Align.CENTER;
            load_more_spinner.valign = Gtk.Align.END;
            load_more_spinner.margin_bottom = 18;
            load_more_spinner.width_request = 22;
            load_more_spinner.height_request = 22;
            load_more_spinner.visible = false;
            grid_overlay.add_overlay(load_more_spinner);

            main_stack.add_named(grid_overlay, "grid");

            detail_view = new PostDetailView();
            detail_view.back.connect(on_back_to_grid);
            detail_view.tag_clicked.connect(on_tag_clicked_from_detail);
            main_stack.add_named(detail_view, "detail");

            root.append(main_stack);

            // ── Bottom bar ──
            bottom_bar = new AppBar(true);

            selection_label = new Gtk.Label("0 selected");
            selection_label.add_css_class("bar-status");
            selection_label.valign = Gtk.Align.CENTER;

            select_all_btn = make_text_btn("Select All", "Select every result for the current search");
            select_all_btn.visible = false;
            select_all_btn.clicked.connect(on_select_all);

            var clear_btn = make_icon_btn("edit-clear-symbolic", "Clear selection");
            clear_btn.clicked.connect(on_clear_selection);

            download_btn = make_text_btn("Download", "Download best quality for selected posts");
            download_btn.add_css_class("suggested-action");
            download_btn.sensitive = false;
            download_btn.clicked.connect(on_download_selected);

            var refresh_btn = make_icon_btn("view-refresh-symbolic", "Refresh results");
            refresh_btn.clicked.connect(on_refresh);

            bottom_bar.pack_start(selection_label);
            bottom_bar.pack_start(select_all_btn);
            bottom_bar.pack_start(clear_btn);
            bottom_bar.pack_end(refresh_btn);
            bottom_bar.pack_end(download_btn);

            root.append(bottom_bar);
            this.content = root;
        }

        private static Gtk.Button make_icon_btn(string icon, string tooltip) {
            var btn = new Gtk.Button.from_icon_name(icon);
            btn.add_css_class("bar-control");
            btn.add_css_class("bar-icon");
            btn.tooltip_text = tooltip;
            btn.valign = Gtk.Align.CENTER;
            return btn;
        }

        private static Gtk.Button make_text_btn(string label, string tooltip) {
            var btn = new Gtk.Button.with_label(label);
            btn.add_css_class("bar-control");
            btn.tooltip_text = tooltip;
            btn.valign = Gtk.Align.CENTER;
            return btn;
        }

        private static Gtk.DropDown make_dropdown(string[] items, int selected, string tooltip) {
            var model = new Gtk.StringList(items);
            var dropdown = new Gtk.DropDown(model, null);
            dropdown.selected = selected;
            dropdown.tooltip_text = tooltip;
            dropdown.valign = Gtk.Align.CENTER;
            dropdown.add_css_class("bar-control");
            return dropdown;
        }

        private int current_limit() {
            uint idx = limit_dropdown.selected;
            if (idx >= LIMIT_VALUES.length) {
                return Config.DEFAULT_LIMIT;
            }
            return LIMIT_VALUES[idx];
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

            show_explicit_switch.notify["active"].connect(() => {
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
            grid_stack.visible_child_name = "grid";
            grid_spinner.visible = true;
            grid_spinner.start();
            load_more_spinner.visible = false;
            load_more_spinner.stop();

            search_posts.begin(tags, current_page);
        }

        private async void search_posts(string tags, int page) {
            int captured_gen = search_gen;
            try {
                var limit = current_limit();
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
                        status_page.title = "No Results";
                        status_page.description = current_tags != ""
                            ? @"No posts found for \"$(current_tags)\""
                            : "Enter tags to search";
                        status_page.icon_name = "edit-find-symbolic";
                        grid_stack.visible_child_name = "empty";
                    } else {
                        grid_stack.visible_child_name = "grid";
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
                        // Roll back so the next scroll can retry this page.
                        if (current_page > 1) {
                            current_page--;
                        }
                        has_more = true;
                        warning("Failed to load page %d: %s", page, err_msg);
                    } else {
                        status_page.title = "Search Failed";
                        status_page.description = err_msg;
                        status_page.icon_name = "dialog-error-symbolic";
                        grid_stack.visible_child_name = "empty";
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

        private void on_clear_selection() {
            stop_select_all_mode();
            int index = 0;
            while (true) {
                var child = flowbox.get_child_at_index(index++);
                if (child == null) break;

                var thumbnail = child.get_child() as ThumbnailWidget;
                if (thumbnail != null) thumbnail.set_selected(false);
            }
            {
                while (selected_posts.length() > 0) {
                    selected_posts.remove(selected_posts.nth_data(0));
                }
            }
            update_selection_ui();
        }

        // ───────────── Detail ─────────────

        private void show_detail(Post post) {
            // Don't keep bulk-select loading while the user is in detail.
            stop_select_all_mode();
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
