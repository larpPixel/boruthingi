namespace Danbooru {
    public enum PreviewSize {
        SMALL,
        MEDIUM,
        LARGE
    }

    public class Config {
        public const string APP_ID = "com.github.danboruthingi";
        public const string VERSION = "0.2.0";
        public const string BASE_URL = "https://danbooru.donmai.us";
        public const string CDN_URL = "https://cdn.donmai.us";
        public const int DEFAULT_LIMIT = 40;
        public const string USER_AGENT = "Danboruthingi/0.2.0";

        /** Square thumbnail pixel size for a preview setting. */
        public static int preview_px(PreviewSize size) {
            switch (size) {
                case PreviewSize.SMALL: return 120;
                case PreviewSize.LARGE: return 260;
                case PreviewSize.MEDIUM:
                default: return 180;
            }
        }

        public static int flowbox_max_children_for_size(PreviewSize size) {
            switch (size) {
                case PreviewSize.SMALL: return 10;
                case PreviewSize.LARGE: return 4;
                case PreviewSize.MEDIUM:
                default: return 6;
            }
        }

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
