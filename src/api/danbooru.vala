using Soup;
using Json;

namespace Danbooru {
    public class Api : GLib.Object {
        private Soup.Session session;

        public Api() {
            session = new Soup.Session();
            session.timeout = 30;
            session.user_agent = Config.USER_AGENT;
        }

        public async List<Post> search_posts(string tags, int page = 1, int limit = 40) throws Error {
            var query_tags = tags.strip();
            if (query_tags == "") {
                query_tags = "rating:s";
            }

            var encoded_tags = Uri.escape_string(query_tags, null, true);
            var url = @"$(Config.BASE_URL)/posts.json?tags=$(encoded_tags)&page=$(page)&limit=$(limit)";
            return parse_posts(yield get_url(url));
        }

        public async List<TagSuggestion> autocomplete_tags(string query) throws Error {
            if (query.length < 2) {
                return new GLib.List<TagSuggestion>();
            }

            var encoded = Uri.escape_string(query, null, true);
            var url = @"$(Config.BASE_URL)/tags.json?search[name_matches]=$(encoded)*&limit=15";
            return parse_tag_suggestions(yield get_url(url));
        }

        public async uint8[] download_bytes(string url, Cancellable? cancellable = null) throws Error {
            var msg = new Soup.Message("GET", url);
            var bytes = yield session.send_and_read_async(msg, Priority.DEFAULT, cancellable);
            ensure_success(msg, url);
            return bytes.get_data();
        }

        public async void download_to_file(string url, string dest_path,
                                           Cancellable? cancellable = null) throws Error {
            var file = GLib.File.new_for_path(dest_path);
            var msg = new Soup.Message("GET", url);
            var bytes = yield session.send_and_read_async(msg, Priority.DEFAULT, cancellable);
            ensure_success(msg, url);
            yield file.replace_contents_async(
                bytes.get_data(), null, false,
                GLib.FileCreateFlags.REPLACE_DESTINATION, cancellable, null
            );
        }

        public async void cache_thumbnail(string url, string md5, string ext) throws Error {
            var path = thumbnail_cache_path(md5, ext);
            if (GLib.File.new_for_path(path).query_exists()) {
                return;
            }
            yield download_to_file(url, path);
        }

        public string? get_cached_thumbnail(string md5, string ext) {
            var path = thumbnail_cache_path(md5, ext);
            return GLib.File.new_for_path(path).query_exists() ? path : null;
        }

        private string thumbnail_cache_path(string md5, string ext) {
            return GLib.Path.build_filename(Config.get_cache_dir(), @"$(md5).$(ext)");
        }

        private async Bytes get_url(string url) throws Error {
            var msg = new Soup.Message("GET", url);
            var bytes = yield session.send_and_read_async(msg, Priority.DEFAULT, null);
            ensure_success(msg, url);
            return bytes;
        }

        private void ensure_success(Soup.Message msg, string url) throws Error {
            if (msg.status_code < 200 || msg.status_code >= 300) {
                throw new IOError.FAILED(
                    "Request for %s failed (HTTP %u)".printf(url, msg.status_code)
                );
            }
        }

        private List<Post> parse_posts(Bytes bytes) throws Error {
            var parser = new Json.Parser();
            parser.load_from_data((string)bytes.get_data());

            var posts = new GLib.List<Post>();
            foreach (var element in parser.get_root().get_array().get_elements()) {
                posts.append(Post.from_json(element.get_object()));
            }
            return posts;
        }

        private List<TagSuggestion> parse_tag_suggestions(Bytes bytes) throws Error {
            var parser = new Json.Parser();
            parser.load_from_data((string)bytes.get_data());

            var suggestions = new GLib.List<TagSuggestion>();
            foreach (var element in parser.get_root().get_array().get_elements()) {
                var obj = element.get_object();
                var name = obj.get_string_member("name");
                var count = obj.get_int_member("post_count");
                int cat = obj.has_member("category") ? (int)obj.get_int_member("category") : 0;
                suggestions.append(new TagSuggestion(name, count, cat));
            }
            return suggestions;
        }
    }
}
