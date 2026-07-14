namespace Danbooru {
    public class MainWindow : Adw.ApplicationWindow {
        private static int[] LIMIT_VALUES = { 10, 20, 30, 40, 50, 60, 80, 100 };
        private static string[] SORT_TAGS = {
            "", "order:score", "order:favcount", "order:rank", "order:date", "order:random"
        };

        private Api api;

        // Search / filters
        private Gtk.SearchEntry search_entry;
        private Gtk.Popover? suggestion_popover;
        private Gtk.ListBox suggestion_list;
        private uint debounce_timer_id = 0;
        private int autocomplete_gen = 0;
        private Gtk.Switch show_explicit_switch;
        private Gtk.DropDown limit_dropdown;
        private Gtk.DropDown size_dropdown;
        private Gtk.DropDown sort_dropdown;

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

        // Search state
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
            default_width = 1200;
            default_height = 850;
            title = "Danboruthingi";

            api = new Api();
            build_ui();
            setup_signals();
            connect_scroll_detection();
            start_fresh_search();
        }

        // ───────────── Build UI ─────────────

        private void build_ui() {
            var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

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
                new string[] { "Small", "Medium", "Large" }, 1, "Thumbnail size"
            );
            limit_dropdown = make_dropdown(limit_labels(), default_limit_index(), "Results per page");
            sort_dropdown = make_dropdown(
                new string[] { "Default", "Score", "Favorites", "Rank", "Newest", "Random" },
                0, "Sort order"
            );

            show_explicit_switch = new Gtk.Switch();
            show_explicit_switch.valign = Gtk.Align.CENTER;
            show_explicit_switch.tooltip_text = "Include explicit posts when no rating tag is set";

            var explicit_label = new Gtk.Label("Explicit");
            explicit_label.add_css_class("bar-label");
            explicit_label.valign = Gtk.Align.CENTER;

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

            main_stack = new Gtk.Stack();
            main_stack.vexpand = true;
            main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

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

            flowbox = new Gtk.FlowBox();
            flowbox.add_css_class("post-grid");
            flowbox.max_children_per_line = Config.flowbox_max_children_for_size(preview_size);
            flowbox.min_children_per_line = 1;
            flowbox.selection_mode = Gtk.SelectionMode.NONE;
            flowbox.column_spacing = 8;
            flowbox.row_spacing = 8;
            flowbox.homogeneous = true;
            flowbox.valign = Gtk.Align.START;
            flowbox.margin_start = 8;
            flowbox.margin_end = 8;
            flowbox.margin_top = 8;
            flowbox.margin_bottom = 8;
            grid_scroll.child = flowbox;
            grid_stack.add_named(grid_scroll, "grid");
            grid_overlay.child = grid_stack;

            grid_spinner = make_spinner(28, Gtk.Align.CENTER, Gtk.Align.CENTER, 0);
            load_more_spinner = make_spinner(22, Gtk.Align.CENTER, Gtk.Align.END, 18);
            grid_overlay.add_overlay(grid_spinner);
            grid_overlay.add_overlay(load_more_spinner);
            main_stack.add_named(grid_overlay, "grid");

            detail_view = new PostDetailView();
            detail_view.back.connect(on_back_to_grid);
            detail_view.tag_clicked.connect(on_tag_clicked_from_detail);
            main_stack.add_named(detail_view, "detail");
            root.append(main_stack);

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
            refresh_btn.clicked.connect(() => start_fresh_search(current_tags));

            bottom_bar.pack_start(selection_label);
            bottom_bar.pack_start(select_all_btn);
            bottom_bar.pack_start(clear_btn);
            bottom_bar.pack_end(refresh_btn);
            bottom_bar.pack_end(download_btn);
            root.append(bottom_bar);

            content = root;
        }

        private static Gtk.Spinner make_spinner(int size, Gtk.Align halign, Gtk.Align valign, int margin_bottom) {
            var spinner = new Gtk.Spinner();
            spinner.halign = halign;
            spinner.valign = valign;
            spinner.width_request = size;
            spinner.height_request = size;
            spinner.margin_bottom = margin_bottom;
            spinner.visible = false;
            return spinner;
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
            var dropdown = new Gtk.DropDown(new Gtk.StringList(items), null);
            dropdown.selected = selected;
            dropdown.tooltip_text = tooltip;
            dropdown.valign = Gtk.Align.CENTER;
            dropdown.add_css_class("bar-control");
            return dropdown;
        }

        private static string[] limit_labels() {
            string[] labels = new string[LIMIT_VALUES.length];
            for (int i = 0; i < LIMIT_VALUES.length; i++) {
                labels[i] = LIMIT_VALUES[i].to_string();
            }
            return labels;
        }

        private static int default_limit_index() {
            for (int i = 0; i < LIMIT_VALUES.length; i++) {
                if (LIMIT_VALUES[i] == Config.DEFAULT_LIMIT) {
                    return i;
                }
            }
            return 3;
        }

        private int current_limit() {
            uint idx = limit_dropdown.selected;
            return idx < LIMIT_VALUES.length ? LIMIT_VALUES[idx] : Config.DEFAULT_LIMIT;
        }

        // ───────────── Signals ─────────────

        private void setup_signals() {
            search_entry.changed.connect(() => {
                autocomplete_gen++;
                if (debounce_timer_id > 0) {
                    Source.remove(debounce_timer_id);
                }
                int gen = autocomplete_gen;
                debounce_timer_id = Timeout.add(300, () => {
                    debounce_timer_id = 0;
                    do_autocomplete.begin(gen);
                    return false;
                });
            });

            size_dropdown.notify["selected"].connect(() => {
                var size = (PreviewSize)size_dropdown.selected;
                if (size == preview_size) {
                    return;
                }
                preview_size = size;
                flowbox.max_children_per_line = Config.flowbox_max_children_for_size(size);
                foreach_thumbnail((thumb) => thumb.set_preview_size(size));
            });

            sort_dropdown.notify["selected"].connect(() => start_fresh_search());
            show_explicit_switch.notify["active"].connect(() => start_fresh_search());
        }

        private void connect_scroll_detection() {
            grid_scroll.vadjustment.value_changed.connect(() => {
                if (loading_more || !has_more || select_all_mode) {
                    return;
                }
                var adj = grid_scroll.vadjustment;
                if (adj.upper - adj.page_size - adj.value < 500.0) {
                    load_more_posts();
                }
            });
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

        private void show_detail(Post post) {
            stop_select_all_mode();
            search_toolbar.visible = false;
            bottom_bar.visible = false;
            detail_view.display_post(post, api);
            main_stack.visible_child_name = "detail";
        }

        // ───────────── Search ─────────────

        private void on_search_clicked() {
            start_fresh_search(build_tag_query());
        }

        private void start_fresh_search(string? explicit_tags = null) {
            search_gen++;
            current_tags = explicit_tags ?? build_tag_query();
            current_page = 1;
            has_more = true;
            loading_more = false;
            stop_select_all_mode();
            select_all_pages_loaded = 0;
            clear_flowbox();
            clear_selection_list();
            update_selection_ui();
            select_all_btn.visible = false;

            grid_stack.visible_child_name = "grid";
            set_spinner(grid_spinner, true);
            set_spinner(load_more_spinner, false);
            search_posts.begin(current_tags, current_page);
        }

        private string build_tag_query() {
            string[] parts = {};
            var text = search_entry.text.strip();
            if (text != "") {
                parts += text;
            }
            if (!show_explicit_switch.active && !text.down().contains("rating:")) {
                parts += "-rating:e";
            }
            uint sort = sort_dropdown.selected;
            if (sort < SORT_TAGS.length && SORT_TAGS[sort] != "") {
                parts += SORT_TAGS[sort];
            }
            return string.joinv(" ", parts);
        }

        private void load_more_posts() {
            if (loading_more || !has_more) {
                return;
            }
            loading_more = true;
            current_page++;
            set_spinner(load_more_spinner, true);
            search_posts.begin(current_tags, current_page);
        }

        private async void search_posts(string tags, int page) {
            int gen = search_gen;
            int limit = current_limit();

            try {
                var posts = yield api.search_posts(tags, page, limit);
                if (gen != search_gen) {
                    return;
                }
                on_search_success(posts, page, limit, gen);
            } catch (Error e) {
                if (gen != search_gen) {
                    return;
                }
                on_search_error(page, e.message);
            }
        }

        private void on_search_success(List<Post> posts, int page, int limit, int gen) {
            populate_grid(posts);
            set_spinner(grid_spinner, false);
            set_spinner(load_more_spinner, false);
            loading_more = false;
            has_more = posts.length() >= limit;

            select_all_btn.visible = search_entry.text.strip() != ""
                && flowbox.get_child_at_index(0) != null;

            if (select_all_mode) {
                continue_select_all(gen);
            }

            if (page == 1 && posts.length() == 0) {
                show_empty(
                    "No Results",
                    current_tags != "" ? @"No posts found for \"$(current_tags)\"" : "Enter tags to search",
                    "edit-find-symbolic"
                );
            } else {
                grid_stack.visible_child_name = "grid";
            }
        }

        private void on_search_error(int page, string err_msg) {
            loading_more = false;
            set_spinner(load_more_spinner, false);
            set_spinner(grid_spinner, false);
            stop_select_all_mode();

            if (page > 1) {
                if (current_page > 1) {
                    current_page--;
                }
                has_more = true;
                warning("Failed to load page %d: %s", page, err_msg);
                return;
            }

            show_empty("Search Failed", err_msg, "dialog-error-symbolic");
        }

        private void show_empty(string title, string description, string icon) {
            status_page.title = title;
            status_page.description = description;
            status_page.icon_name = icon;
            grid_stack.visible_child_name = "empty";
        }

        private static void set_spinner(Gtk.Spinner spinner, bool active) {
            spinner.visible = active;
            if (active) {
                spinner.start();
            } else {
                spinner.stop();
            }
        }

        // ───────────── Grid ─────────────

        private void populate_grid(List<Post> posts) {
            foreach (var post in posts) {
                var thumb = new ThumbnailWidget(post, preview_size);
                thumb.clicked.connect(show_detail);
                thumb.selection_toggled.connect(on_selection_changed);
                flowbox.append(thumb);
                if (select_all_mode) {
                    thumb.set_selected(true);
                }
                thumb.load_thumbnail.begin(api);
            }
        }

        private void clear_flowbox() {
            Gtk.Widget? child;
            while ((child = flowbox.get_child_at_index(0)) != null) {
                flowbox.remove(child);
            }
        }

        private delegate void ThumbnailFn(ThumbnailWidget thumb);

        private void foreach_thumbnail(ThumbnailFn fn) {
            int i = 0;
            while (true) {
                var child = flowbox.get_child_at_index(i++);
                if (child == null) {
                    break;
                }
                var thumb = child.get_child() as ThumbnailWidget;
                if (thumb != null) {
                    fn(thumb);
                }
            }
        }

        private int loaded_thumbnail_count() {
            int count = 0;
            while (flowbox.get_child_at_index(count) != null) {
                count++;
            }
            return count;
        }

        // ───────────── Selection ─────────────

        private void on_selection_changed(Post post, bool selected) {
            if (selected) {
                if (find_selected(post.id) == null) {
                    selected_posts.append(post);
                }
            } else {
                var existing = find_selected(post.id);
                if (existing != null) {
                    selected_posts.remove(existing);
                }
            }
            update_selection_ui();
        }

        private Post? find_selected(int64 id) {
            foreach (var p in selected_posts) {
                if (p.id == id) {
                    return p;
                }
            }
            return null;
        }

        private void clear_selection_list() {
            while (selected_posts.length() > 0) {
                selected_posts.remove(selected_posts.nth_data(0));
            }
        }

        private void update_selection_ui() {
            uint count = selected_posts.length();
            selection_label.label = @"$(count) selected";
            download_btn.sensitive = count > 0;
            select_all_btn.sensitive = count < loaded_thumbnail_count() || has_more;
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

            foreach_thumbnail((thumb) => thumb.set_selected(true));

            if (has_more) {
                load_more_posts();
            } else {
                stop_select_all_mode();
            }
        }

        private void continue_select_all(int gen) {
            select_all_pages_loaded++;
            if (has_more && select_all_pages_loaded < MAX_SELECT_ALL_PAGES) {
                Timeout.add(50, () => {
                    if (gen == search_gen && select_all_mode) {
                        load_more_posts();
                    }
                    return false;
                });
            } else {
                if (select_all_pages_loaded >= MAX_SELECT_ALL_PAGES) {
                    warning("Select All stopped at %d pages", MAX_SELECT_ALL_PAGES);
                }
                stop_select_all_mode();
            }
        }

        private void stop_select_all_mode() {
            if (!select_all_mode) {
                return;
            }
            select_all_mode = false;
            select_all_btn.label = "Select All";
            select_all_btn.tooltip_text = "Select every result for the current search";
        }

        private void on_clear_selection() {
            stop_select_all_mode();
            foreach_thumbnail((thumb) => thumb.set_selected(false));
            clear_selection_list();
            update_selection_ui();
        }

        private void on_download_selected() {
            if (selected_posts.length() == 0) {
                return;
            }

            Post[] posts_arr = {};
            foreach (var p in selected_posts) {
                posts_arr += p;
            }

            var dialog = new DownloadDialog(posts_arr);
            dialog.transient_for = this;
            dialog.present();
        }

        // ───────────── Autocomplete ─────────────

        private async void do_autocomplete(int gen) {
            var query = last_token(search_entry.text);
            if (query.length < 2) {
                hide_suggestions();
                return;
            }

            try {
                var suggestions = yield api.autocomplete_tags(query);
                if (gen != autocomplete_gen) {
                    return;
                }
                if (suggestions.length() > 0) {
                    show_suggestions(suggestions);
                } else {
                    hide_suggestions();
                }
            } catch (Error e) {
                // Non-critical
            }
        }

        private static string last_token(string text) {
            var last_space = text.last_index_of(" ");
            return last_space >= 0 ? text.substring(last_space + 1) : text;
        }

        private void show_suggestions(List<TagSuggestion> suggestions) {
            ensure_suggestion_popover();

            while (true) {
                var row = suggestion_list.get_row_at_index(0);
                if (row == null) break;
                suggestion_list.remove(row);
            }

            string[] cat_names = { "General", "Artist", "Character", "Copyright", "Meta" };

            foreach (var sug in suggestions) {
                var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
                box.margin_start = 8;
                box.margin_end = 8;
                box.margin_top = 4;
                box.margin_bottom = 4;

                var name_label = new Gtk.Label(sug.name);
                name_label.halign = Gtk.Align.START;
                name_label.hexpand = true;
                name_label.ellipsize = Pango.EllipsizeMode.END;
                name_label.add_css_class("suggestion-name");

                var count_label = new Gtk.Label(@"$(sug.post_count)");
                count_label.add_css_class("suggestion-count");

                var cat_label = new Gtk.Label(cat_names[sug.category.clamp(0, 4)]);
                cat_label.add_css_class("suggestion-cat");

                box.append(name_label);
                box.append(count_label);
                box.append(cat_label);

                var row = new Gtk.ListBoxRow();
                row.child = box;
                row.selectable = false;
                suggestion_list.append(row);
            }

            if (suggestion_popover.get_parent() == null) {
                suggestion_popover.set_parent(search_entry);
            }
            suggestion_popover.popup();
        }

        private void ensure_suggestion_popover() {
            if (suggestion_popover != null) {
                return;
            }

            suggestion_popover = new Gtk.Popover();
            suggestion_popover.has_arrow = false;
            suggestion_popover.position = Gtk.PositionType.BOTTOM;
            suggestion_popover.autohide = true;
            suggestion_popover.can_focus = false;
            suggestion_popover.focusable = false;

            suggestion_list = new Gtk.ListBox();
            suggestion_list.add_css_class("boxed-list");
            suggestion_list.selection_mode = Gtk.SelectionMode.NONE;
            suggestion_popover.child = suggestion_list;

            suggestion_list.row_activated.connect((row) => {
                var box = row.get_child() as Gtk.Box;
                var name_label = box != null ? box.get_first_child() as Gtk.Label : null;
                if (name_label != null) {
                    apply_suggestion(name_label.label);
                }
            });
        }

        private void hide_suggestions() {
            if (suggestion_popover != null) {
                suggestion_popover.popdown();
            }
        }

        private void apply_suggestion(string tag) {
            var text = search_entry.text;
            var last_space = text.last_index_of(" ");
            var prefix = last_space >= 0 ? text.substring(0, last_space + 1) : "";
            search_entry.text = prefix + tag + " ";
            search_entry.set_position(-1);
            hide_suggestions();
            search_entry.grab_focus();
        }
    }
}
