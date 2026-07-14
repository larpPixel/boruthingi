using Json;

namespace Danbooru {
    public class Post : GLib.Object {
        public int64 id { get; set; }
        public string created_at { get; set; default = ""; }
        public int score { get; set; default = 0; }
        public string source { get; set; default = ""; }
        public string md5 { get; set; default = ""; }
        public string rating { get; set; default = "s"; }
        public int image_width { get; set; default = 0; }
        public int image_height { get; set; default = 0; }
        public string tag_string { get; set; default = ""; }
        public string tag_string_general { get; set; default = ""; }
        public string tag_string_artist { get; set; default = ""; }
        public string tag_string_character { get; set; default = ""; }
        public string tag_string_copyright { get; set; default = ""; }
        public string tag_string_meta { get; set; default = ""; }
        public int64 file_size { get; set; default = 0; }
        public string file_ext { get; set; default = ""; }
        public int64 pixiv_id { get; set; default = -1; }
        public string? file_url { get; set; default = null; }
        public string? large_file_url { get; set; default = null; }
        public string? preview_file_url { get; set; default = null; }
        public string? best_available_url { get; set; default = null; }
        public string best_available_ext { get; set; default = ""; }

        public string display_rating {
            owned get {
                switch (rating) {
                    case "s": return "Safe";
                    case "q": return "Questionable";
                    case "e": return "Explicit";
                    default: return rating;
                }
            }
        }

        public string file_size_display {
            owned get {
                if (file_size < 1024) return @"$(file_size) B";
                if (file_size < 1024 * 1024) return @"$(file_size / 1024) KB";
                return @"$(file_size / (1024 * 1024)) MB";
            }
        }

        public string original_url {
            owned get {
                return best_available_url ?? file_url ?? large_file_url ?? preview_file_url ?? "";
            }
        }

        public string download_file_ext {
            owned get {
                return best_available_ext != "" ? best_available_ext : file_ext;
            }
        }

        public string large_url {
            owned get {
                if (large_file_url != null && large_file_url != "") return large_file_url;
                if (md5 == "") return "";
                return @"$(Config.CDN_URL)/original/$(md5.substring(0,2))/$(md5.substring(2,2))/$(md5).$(file_ext)";
            }
        }

        public string thumbnail_url {
            owned get {
                if (preview_file_url != null && preview_file_url != "") return preview_file_url;
                if (md5 == "") return "";
                return @"$(Config.CDN_URL)/preview/$(md5.substring(0,2))/$(md5.substring(2,2))/$(md5).jpg";
            }
        }

        public string page_url {
            owned get {
                return @"$(Config.BASE_URL)/posts/$(id)";
            }
        }

        public string rating_css_key {
            owned get {
                switch (rating) {
                    case "s": return "s";
                    case "q": return "q";
                    case "e": return "e";
                    default: return rating;
                }
            }
        }

        public static Post from_json(Json.Object obj) {
            var post = new Post();
            post.id = obj.get_int_member("id");
            post.created_at = get_string(obj, "created_at");
            post.score = (int)obj.get_int_member("score");
            post.source = get_string(obj, "source");
            post.md5 = get_string(obj, "md5");
            post.rating = get_string(obj, "rating");
            post.image_width = (int)obj.get_int_member("image_width");
            post.image_height = (int)obj.get_int_member("image_height");
            post.tag_string = get_string(obj, "tag_string");
            post.tag_string_general = get_string(obj, "tag_string_general");
            post.tag_string_artist = get_string(obj, "tag_string_artist");
            post.tag_string_character = get_string(obj, "tag_string_character");
            post.tag_string_copyright = get_string(obj, "tag_string_copyright");
            post.tag_string_meta = get_string(obj, "tag_string_meta");
            post.file_size = (int64)obj.get_int_member("file_size");
            post.file_ext = get_string(obj, "file_ext");
            post.pixiv_id = obj.has_member("pixiv_id") && !obj.get_null_member("pixiv_id")
                ? (int64)obj.get_int_member("pixiv_id") : -1;
            post.file_url = get_string_nullable(obj, "file_url");
            post.large_file_url = get_string_nullable(obj, "large_file_url");
            post.preview_file_url = get_string_nullable(obj, "preview_file_url");
            populate_best_available_asset(obj, post);
            return post;
        }

        private static void populate_best_available_asset(Json.Object obj, Post post) {
            // Danbooru's file_url is the full-resolution file when it is present.
            if (post.file_url != null && post.file_url != "") {
                post.best_available_url = post.file_url;
                post.best_available_ext = post.file_ext;
                return;
            }

            string? fallback_url = post.file_url;
            string fallback_ext = post.file_ext;
            int64 largest_area = -1;

            if (!obj.has_member("media_asset") || obj.get_null_member("media_asset")) {
                post.best_available_url = fallback_url;
                post.best_available_ext = fallback_ext;
                return;
            }

            var asset = obj.get_object_member("media_asset");
            if (!asset.has_member("variants") || asset.get_null_member("variants")) {
                post.best_available_url = fallback_url;
                post.best_available_ext = fallback_ext;
                return;
            }

            foreach (var element in asset.get_array_member("variants").get_elements()) {
                var variant = element.get_object();
                var url = get_string(variant, "url");
                if (url == "") continue;

                var type = get_string(variant, "type");
                var ext = get_string(variant, "file_ext");
                if (type == "original") {
                    post.best_available_url = url;
                    post.best_available_ext = ext != "" ? ext : post.file_ext;
                    return;
                }

                int64 width = variant.has_member("width") ? variant.get_int_member("width") : 0;
                int64 height = variant.has_member("height") ? variant.get_int_member("height") : 0;
                int64 area = width * height;
                if (area > largest_area) {
                    largest_area = area;
                    fallback_url = url;
                    fallback_ext = ext != "" ? ext : post.file_ext;
                }
            }

            post.best_available_url = fallback_url;
            post.best_available_ext = fallback_ext;
        }

        private static string get_string(Json.Object obj, string name) {
            if (obj.has_member(name) && !obj.get_null_member(name)) {
                return obj.get_string_member(name);
            }
            return "";
        }

        private static string? get_string_nullable(Json.Object obj, string name) {
            if (obj.has_member(name) && !obj.get_null_member(name)) {
                return obj.get_string_member(name);
            }
            return null;
        }
    }

    public class TagSuggestion : GLib.Object {
        public string name { get; set; }
        public int64 post_count { get; set; }
        public int category { get; set; }

        public TagSuggestion(string name, int64 post_count, int category) {
            this.name = name;
            this.post_count = post_count;
            this.category = category;
        }
    }
}
