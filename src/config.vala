namespace Danbooru {
    public class Config {
        public const string APP_ID = "com.github.danboruthingi";
        public const string APP_NAME = "Danboruthingi";
        public const string VERSION = "0.1.0";
        public const string BASE_URL = "https://danbooru.donmai.us";
        public const string CDN_URL = "https://cdn.donmai.us";
        public const int DEFAULT_LIMIT = 40;
        public const int THUMBNAIL_WIDTH = 200;
        public const int THUMBNAIL_HEIGHT = 250;
        public const int PREVIEW_WIDTH = 180;
        public const int PREVIEW_HEIGHT = 180;
        public const string USER_AGENT = "Danboruthingi/0.1.0";

        public static string get_cache_dir() {
            string? xdg = Environment.get_variable("XDG_CACHE_HOME");
            if (xdg == null) {
                xdg = Path.build_filename(Environment.get_home_dir(), ".cache");
            }
            var dir = Path.build_filename(xdg, "danboruthingi", "thumbnails");
            var f = GLib.File.new_for_path(dir);
            if (!f.query_exists()) {
                try {
                    f.make_directory_with_parents();
                } catch (Error e) {
                    warning("Could not create cache dir: %s", e.message);
                }
            }
            return dir;
        }
    }
}
