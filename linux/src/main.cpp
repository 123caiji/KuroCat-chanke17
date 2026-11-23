#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include <cairo.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <limits.h>
#include <string>
#include <thread>
#include <vector>
#include <algorithm>
#include <unistd.h>
#include "KeyMap.hpp"
#include "InputEngine.hpp"
#include "CatPhysics.hpp"
#include "CatRenderer.hpp"

#include <sys/stat.h>
#include <cstdlib>

static constexpr const char* APP_VERSION = "1.3.2";
static constexpr const char* UPDATE_PAGE_URL = "https://kurocat-download.app.workbuddy.host/?sharecode=JVAABIVZ7L";
#if defined(__aarch64__) || defined(_M_ARM64)
static constexpr const char* UPDATE_TAR_URL = "https://kurocat-download.app.workbuddy.host/downloads/KuroCat-Linux-arm64.tar.gz?sharecode=JVAABIVZ7L";
#else
static constexpr const char* UPDATE_TAR_URL = "https://kurocat-download.app.workbuddy.host/downloads/KuroCat-Linux-x86_64.tar.gz?sharecode=JVAABIVZ7L";
#endif

struct LinuxApp {
    GtkWidget* window = nullptr;
    GtkWidget* drawArea = nullptr;
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    GtkStatusIcon* trayIcon = nullptr;
    G_GNUC_END_IGNORE_DEPRECATIONS

    CatSettings settings;
    InputEngine input;
    CatPhysics physics;

    bool isVisible = true;
    bool isDragging = false;
    bool clickThroughTemporarilyUnlocked = false;
    double dragStartRootX = 0.0, dragStartRootY = 0.0;
    int dragStartWinX = 0, dragStartWinY = 0;

    bool hasLastHover = false;
    Pt lastHoverCanvas = { 0.0f, 0.0f };
    double lastTickTime = 0.0;

    bool demoActive = false;
    double demoStartTime = 0.0;
    int demoStepIdx = 0;

    std::string availableUpdateVersion;
    std::string availableUpdateUrl;
    bool isUpdating = false;
};

static LinuxApp* g_app = nullptr;

// MARK: - Launch at Login (Freedesktop XDG Autostart: Ubuntu/Debian/Deepin/统信 UOS/KDE/GNOME)

static std::string getAutostartDir() {
    const char* xdg = std::getenv("XDG_CONFIG_HOME");
    if (xdg && xdg[0] != '\0') return std::string(xdg) + "/autostart";
    const char* home = std::getenv("HOME");
    return std::string(home ? home : "/tmp") + "/.config/autostart";
}

static std::string getAutostartFilePath() {
    return getAutostartDir() + "/kurocat.desktop";
}

static std::string getSelfExePath() {
    char buf[PATH_MAX] = {0};
    ssize_t len = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
    if (len > 0) {
        buf[len] = '\0';
        return std::string(buf);
    }
    return "kurocat";
}

static bool isAutoStartEnabled() {
    return access(getAutostartFilePath().c_str(), F_OK) == 0;
}

static bool setAutoStartEnabled(bool enable) {
    std::string path = getAutostartFilePath();
    if (!enable) {
        std::remove(path.c_str());
        return true;
    }
    std::string dir = getAutostartDir();
    g_mkdir_with_parents(dir.c_str(), 0755);
    std::string exe = getSelfExePath();
    std::ofstream f(path);
    if (!f.is_open()) return false;
    f << "[Desktop Entry]\n"
      << "Type=Application\n"
      << "Name=KuroCat\n"
      << "Name[zh_CN]=KuroCat 黑猫桌宠\n"
      << "Comment=Native desktop keyboard & mouse cat pet\n"
      << "Exec=\"" << exe << "\"\n"
      << "Icon=kurocat\n"
      << "Terminal=false\n"
      << "X-GNOME-Autostart-enabled=true\n";
    return f.good();
}

static void updateInputShape(LinuxApp& app) {
    if (!app.window || !gtk_widget_get_realized(app.window)) return;
    if (app.settings.fullClickThrough && !app.clickThroughTemporarilyUnlocked) {
        cairo_region_t* empty = cairo_region_create();
        gtk_widget_input_shape_combine_region(app.window, empty);
        cairo_region_destroy(empty);
        return;
    }

    // Smart per-area input mask: transparent corners pass clicks straight through,
    // while the cat head/body & mini keyboard remain interactive for petting, dragging & right-click!
    float s = app.settings.scale;
    cairo_region_t* reg = cairo_region_create();
    cairo_rectangle_int_t catBox = {
        (int)(128 * s), (int)(72 * s), (int)(116 * s), (int)(172 * s)
    };
    cairo_rectangle_int_t kbBox = {
        (int)(56 * s), (int)(230 * s), (int)(242 * s), (int)(72 * s)
    };
    cairo_region_union_rectangle(reg, &catBox);
    cairo_region_union_rectangle(reg, &kbBox);
    gtk_widget_input_shape_combine_region(app.window, reg);
    cairo_region_destroy(reg);
}

static void getDefaultOrigin(int w, int h, int& outX, int& outY) {
    GdkDisplay* dpy = gdk_display_get_default();
    GdkMonitor* mon = dpy ? gdk_display_get_primary_monitor(dpy) : nullptr;
    if (!mon && dpy) mon = gdk_display_get_monitor(dpy, 0);
    GdkRectangle geo = { 0, 0, 1440, 900 };
    if (mon) gdk_monitor_get_workarea(mon, &geo);
    outX = geo.x + geo.width - w - 24;
    outY = geo.y + geo.height - h - 16;
}

static void applyWindowScaleAndPos(LinuxApp& app, bool anchorBottomCenter) {
    int newW = (int)std::round(CatPhysics::CanvasWidth * app.settings.scale);
    int newH = (int)std::round(CatPhysics::CanvasHeight * app.settings.scale);

    int x = app.settings.posX;
    int y = app.settings.posY;
    if (anchorBottomCenter && app.window) {
        int oldX = 0, oldY = 0, oldW = 0, oldH = 0;
        gtk_window_get_position(GTK_WINDOW(app.window), &oldX, &oldY);
        gtk_window_get_size(GTK_WINDOW(app.window), &oldW, &oldH);
        x = oldX + oldW / 2 - newW / 2;
        y = oldY + oldH - newH;
    } else if (x == -99999 || y == -99999) {
        getDefaultOrigin(newW, newH, x, y);
    }

    app.settings.posX = x;
    app.settings.posY = y;
    gtk_window_resize(GTK_WINDOW(app.window), newW, newH);
    gtk_window_move(GTK_WINDOW(app.window), x, y);
    gtk_window_set_keep_above(GTK_WINDOW(app.window), app.settings.alwaysOnTop ? TRUE : FALSE);
    updateInputShape(app);
    app.settings.save();
}

static void openUrlInBrowser(const std::string& url) {
    pid_t pid = fork();
    if (pid == 0) {
        execlp("xdg-open", "xdg-open", url.c_str(), nullptr);
        _exit(127);
    }
}

struct LinuxUpdateResult {
    bool ok = false;
    bool manual = false;
    bool hasUpdate = false;
    std::string latestTag;
    std::string releaseUrl;
};

static std::string extractJsonField(const std::string& json, const char* fieldName) {
    std::string key = std::string("\"") + fieldName + "\"";
    size_t pos = json.find(key);
    if (pos == std::string::npos) return "";
    pos = json.find(':', pos + key.size());
    if (pos == std::string::npos) return "";
    pos = json.find('"', pos + 1);
    if (pos == std::string::npos) return "";
    size_t end = json.find('"', pos + 1);
    if (end == std::string::npos) return "";
    return json.substr(pos + 1, end - pos - 1);
}

static bool isSemVerNewer(const std::string& lhs, const std::string& rhs) {
    auto parse = [](const std::string& v) {
        std::vector<int> parts;
        size_t i = 0;
        while (i < v.size() && (v[i] == 'v' || v[i] == 'V' || v[i] == ' ')) i++;
        int cur = 0; bool inNum = false;
        for (; i < v.size(); ++i) {
            if (v[i] >= '0' && v[i] <= '9') { cur = cur * 10 + (v[i] - '0'); inNum = true; }
            else if (v[i] == '.') { parts.push_back(inNum ? cur : 0); cur = 0; inNum = false; }
            else break;
        }
        if (inNum) parts.push_back(cur);
        return parts;
    };
    auto a = parse(lhs), b = parse(rhs);
    size_t n = std::max(a.size(), b.size());
    for (size_t i = 0; i < n; ++i) {
        int va = i < a.size() ? a[i] : 0;
        int vb = i < b.size() ? b[i] : 0;
        if (va != vb) return va > vb;
    }
    return false;
}

static std::string extractVersionFromHtml(const std::string& html) {
    auto parseVerAt = [&](size_t pos) -> std::string {
        if (pos >= html.size() || (html[pos] != 'v' && html[pos] != 'V')) return "";
        size_t i = pos + 1;
        int dots = 0;
        std::string ver = "v";
        while (i < html.size()) {
            char c = html[i];
            if (c >= '0' && c <= '9') { ver.push_back(c); }
            else if (c == '.') { dots++; ver.push_back(c); }
            else break;
            i++;
        }
        return (dots >= 2 && ver.size() > 5) ? ver : "";
    };

    size_t mPos = html.find("已发布");
    if (mPos != std::string::npos) {
        size_t searchStart = (mPos > 32) ? (mPos - 32) : 0;
        for (size_t i = mPos; i > searchStart; --i) {
            if (html[i - 1] == 'v' || html[i - 1] == 'V') {
                std::string v = parseVerAt(i - 1);
                if (!v.empty()) return v;
            }
        }
    }
    size_t vPos = html.find("版本 ");
    if (vPos != std::string::npos) {
        std::string v = parseVerAt(vPos + 7);
        if (!v.empty()) return v;
    }
    return "";
}

static std::string fetchUrlBody(const char* url) {
    std::string cmd = std::string("curl -fsSL --max-time 8 -A KuroCat/1.3.2 '") + url +
        "' 2>/dev/null || wget -qO- --timeout=8 '" + url + "' 2>/dev/null";
    std::string body;
    if (FILE* fp = popen(cmd.c_str(), "r")) {
        char buf[1024];
        while (size_t n = std::fread(buf, 1, sizeof(buf), fp)) body.append(buf, n);
        pclose(fp);
    }
    return body;
}

static void startInAppUpdate();

static void startAsyncUpdateCheck(bool manual, int delayMs = 0) {
    std::thread([manual, delayMs]() {
        if (delayMs > 0) usleep((useconds_t)delayMs * 1000);
        auto* res = new LinuxUpdateResult();
        res->manual = manual;

        std::string body = fetchUrlBody("https://kurocat-download.app.workbuddy.host/version.json?sharecode=JVAABIVZ7L");
        std::string tag = extractJsonField(body, "tag_name");
        std::string url = extractJsonField(body, "html_url");

        if (tag.empty()) {
            std::string html = fetchUrlBody(UPDATE_PAGE_URL);
            tag = extractVersionFromHtml(html);
        }

        if (!tag.empty()) {
            res->ok = true;
            res->latestTag = tag;
            res->releaseUrl = url.empty() ? UPDATE_PAGE_URL : url;
            res->hasUpdate = isSemVerNewer(tag, APP_VERSION);
        }

        g_idle_add(+[](gpointer data) -> gboolean {
            auto* r = static_cast<LinuxUpdateResult*>(data);
            if (g_app && r->ok && r->hasUpdate) {
                g_app->availableUpdateVersion = r->latestTag;
                g_app->availableUpdateUrl = r->releaseUrl;
                GtkWidget* dlg = gtk_message_dialog_new(
                    nullptr, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_YES_NO,
                    "发现 KuroCat 新版本 %s", r->latestTag.c_str());
                gtk_message_dialog_format_secondary_text(
                    GTK_MESSAGE_DIALOG(dlg),
                    "当前版本：v%s\n最新版本：%s\n\n是否立即在软件内自动下载并更新重启？",
                    APP_VERSION, r->latestTag.c_str());
                int resp = gtk_dialog_run(GTK_DIALOG(dlg));
                gtk_widget_destroy(dlg);
                if (resp == GTK_RESPONSE_YES) {
                    startInAppUpdate();
                }
            } else if (r->manual) {
                GtkWidget* dlg = gtk_message_dialog_new(
                    nullptr, GTK_DIALOG_MODAL,
                    r->ok ? GTK_MESSAGE_INFO : GTK_MESSAGE_WARNING, GTK_BUTTONS_OK,
                    "%s", r->ok ? "已是最新版本" : "检查更新失败");
                gtk_message_dialog_format_secondary_text(
                    GTK_MESSAGE_DIALOG(dlg),
                    "%s", r->ok ? "当前版本已是最新版本。" : "无法连接到更新服务器，请稍后重试或检查网络连接。");
                gtk_dialog_run(GTK_DIALOG(dlg));
                gtk_widget_destroy(dlg);
            }
            delete r;
            return G_SOURCE_REMOVE;
        }, res);
    }).detach();
}

static void startInAppUpdate() {
    if (!g_app || g_app->isUpdating) return;
    g_app->isUpdating = true;

    std::thread([]() {
        bool ok = false;
        char exeBuf[PATH_MAX] = {};
        ssize_t exeLen = readlink("/proc/self/exe", exeBuf, sizeof(exeBuf) - 1);
        std::string exePath = (exeLen > 0) ? std::string(exeBuf, exeLen) : "";

        std::string workDir = "/tmp/kurocat_upd_" + std::to_string((long)getpid());
        std::string tarPath = workDir + "/update.tar.gz";
        std::string newBin = workDir + "/kurocat";

        if (!exePath.empty()) {
            std::string dlCmd = "mkdir -p '" + workDir + "' && (curl -fsSL --max-time 60 -o '" + tarPath +
                "' '" + UPDATE_TAR_URL + "' || wget -qO '" + tarPath + "' --timeout=60 '" + UPDATE_TAR_URL +
                "') && tar -xzf '" + tarPath + "' -C '" + workDir + "'";
            if (std::system(dlCmd.c_str()) == 0) {
                struct stat st{};
                if (stat(newBin.c_str(), &st) == 0 && st.st_size > 10000) {
                    size_t slash = exePath.rfind('/');
                    std::string exeDir = (slash != std::string::npos) ? exePath.substr(0, slash) : ".";
                    bool writable = (access(exeDir.c_str(), W_OK) == 0);
                    std::string installCmd = writable
                        ? ("mv -f '" + newBin + "' '" + exePath + "' && chmod 755 '" + exePath + "'")
                        : ("pkexec sh -c \"cp '" + newBin + "' '" + exePath + "' && chmod 755 '" + exePath + "'\"");
                    if (std::system(installCmd.c_str()) == 0) {
                        ok = true;
                    }
                }
            }
        }
        std::string cleanupCmd = "rm -rf '" + workDir + "'";
        (void)std::system(cleanupCmd.c_str());

        auto* res = new std::pair<bool, std::string>(ok, exePath);
        g_idle_add(+[](gpointer data) -> gboolean {
            auto* p = static_cast<std::pair<bool, std::string>*>(data);
            if (g_app) g_app->isUpdating = false;
            if (p->first && !p->second.empty()) {
                pid_t pid = fork();
                if (pid == 0) {
                    execl(p->second.c_str(), p->second.c_str(), nullptr);
                    _exit(127);
                }
                gtk_main_quit();
            } else {
                GtkWidget* dlg = gtk_message_dialog_new(
                    nullptr, GTK_DIALOG_MODAL, GTK_MESSAGE_WARNING, GTK_BUTTONS_YES_NO,
                    "自动更新失败");
                gtk_message_dialog_format_secondary_text(
                    GTK_MESSAGE_DIALOG(dlg),
                    "自动下载或替换安装包失败，是否打开下载页手动下载？");
                int resp = gtk_dialog_run(GTK_DIALOG(dlg));
                gtk_widget_destroy(dlg);
                if (resp == GTK_RESPONSE_YES) {
                    std::string url = (g_app && !g_app->availableUpdateUrl.empty())
                        ? g_app->availableUpdateUrl : UPDATE_PAGE_URL;
                    openUrlInBrowser(url);
                }
            }
            delete p;
            return G_SOURCE_REMOVE;
        }, res);
    }).detach();
}

static GdkPixbuf* createCatTrayPixbuf() {
    constexpr int sz = 32;
    cairo_surface_t* surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, sz, sz);
    cairo_t* cr = cairo_create(surf);
    cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

    // Matte black cat head silhouette
    cairo_set_source_rgba(cr, 0.085, 0.085, 0.10, 1.0);
    cairo_move_to(cr, 4, 15); cairo_line_to(cr, 6, 3); cairo_line_to(cr, 14, 11); cairo_close_path(cr); cairo_fill(cr);
    cairo_move_to(cr, 28, 15); cairo_line_to(cr, 26, 3); cairo_line_to(cr, 18, 11); cairo_close_path(cr); cairo_fill(cr);
    cairo_save(cr); cairo_translate(cr, 16, 18.5); cairo_scale(cr, 12.0, 10.5); cairo_arc(cr, 0, 0, 1.0, 0, 6.2832); cairo_restore(cr); cairo_fill(cr);

    // Chartreuse glowing eyes
    cairo_set_source_rgba(cr, 0.79, 0.95, 0.25, 1.0);
    cairo_save(cr); cairo_translate(cr, 11.5, 17.2); cairo_scale(cr, 3.0, 2.6); cairo_arc(cr, 0, 0, 1.0, 0, 6.2832); cairo_restore(cr); cairo_fill(cr);
    cairo_save(cr); cairo_translate(cr, 20.5, 17.2); cairo_scale(cr, 3.0, 2.6); cairo_arc(cr, 0, 0, 1.0, 0, 6.2832); cairo_restore(cr); cairo_fill(cr);

    cairo_set_source_rgba(cr, 0.08, 0.08, 0.10, 1.0);
    cairo_save(cr); cairo_translate(cr, 11.5, 17.2); cairo_scale(cr, 0.9, 1.9); cairo_arc(cr, 0, 0, 1.0, 0, 6.2832); cairo_restore(cr); cairo_fill(cr);
    cairo_save(cr); cairo_translate(cr, 20.5, 17.2); cairo_scale(cr, 0.9, 1.9); cairo_arc(cr, 0, 0, 1.0, 0, 6.2832); cairo_restore(cr); cairo_fill(cr);

    GdkPixbuf* pb = gdk_pixbuf_get_from_surface(surf, 0, 0, sz, sz);
    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    return pb;
}

static void showPopupMenu(LinuxApp& app, GdkEventButton* evt) {
    GtkWidget* menu = gtk_menu_new();

    auto addDisabled = [&](const std::string& label) {
        GtkWidget* it = gtk_menu_item_new_with_label(label.c_str());
        gtk_widget_set_sensitive(it, FALSE);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), it);
    };
    auto addSep = [&]() {
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());
    };
    auto addCheck = [&](const char* label, bool checked, GCallback cb, gpointer data = nullptr) {
        GtkWidget* it = gtk_check_menu_item_new_with_label(label);
        gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(it), checked ? TRUE : FALSE);
        g_signal_connect(it, "toggled", cb, data);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), it);
    };
    auto addAction = [&](const char* label, GCallback cb, gpointer data = nullptr) {
        GtkWidget* it = gtk_menu_item_new_with_label(label);
        g_signal_connect(it, "activate", cb, data);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), it);
    };

    addDisabled(app.input.statusText());
    addDisabled("今日击键 " + std::to_string(app.input.totalKeystrokesToday)
        + "  ·  KPM " + std::to_string(app.input.currentKPM())
        + "  ·  摸猫 " + std::to_string(app.physics.totalPetSessions) + " 次");
    addSep();

    addAction(app.isVisible ? "隐藏小猫" : "显示小猫", G_CALLBACK(+[](GtkMenuItem*, gpointer) {
        g_app->isVisible = !g_app->isVisible;
        if (g_app->isVisible) gtk_widget_show(g_app->window);
        else gtk_widget_hide(g_app->window);
    }));

    addCheck("完全鼠标穿透 (按住 Alt 可临时右键/拖动)", app.settings.fullClickThrough, G_CALLBACK(+[](GtkCheckMenuItem* item, gpointer) {
        g_app->settings.fullClickThrough = gtk_check_menu_item_get_active(item);
        updateInputShape(*g_app);
        g_app->settings.save();
    }));

    addCheck("窗口置顶显示", app.settings.alwaysOnTop, G_CALLBACK(+[](GtkCheckMenuItem* item, gpointer) {
        g_app->settings.alwaysOnTop = gtk_check_menu_item_get_active(item);
        applyWindowScaleAndPos(*g_app, false);
    }));

    addCheck("开机自动启动", isAutoStartEnabled(), G_CALLBACK(+[](GtkCheckMenuItem* item, gpointer) {
        setAutoStartEnabled(gtk_check_menu_item_get_active(item));
    }));

    addSep();

    addCheck("显示按键气泡 ([S] [W] [⇧])", app.settings.showKeyBadges, G_CALLBACK(+[](GtkCheckMenuItem* item, gpointer) {
        g_app->settings.showKeyBadges = gtk_check_menu_item_get_active(item);
        g_app->settings.save();
    }));
    addCheck("显示鼠标点击气泡 ([左键] [右键])", app.settings.showMouseBadges, G_CALLBACK(+[](GtkCheckMenuItem* item, gpointer) {
        g_app->settings.showMouseBadges = gtk_check_menu_item_get_active(item);
        g_app->settings.save();
    }));
    addCheck("显示键盘字符", app.settings.showKeyLegends, G_CALLBACK(+[](GtkCheckMenuItem* item, gpointer) {
        g_app->settings.showKeyLegends = gtk_check_menu_item_get_active(item);
        g_app->settings.save();
    }));
    addCheck("3键同时按「用脚按」彩蛋 🐾", app.settings.footEasterEgg, G_CALLBACK(+[](GtkCheckMenuItem* item, gpointer) {
        g_app->settings.footEasterEgg = gtk_check_menu_item_get_active(item);
        g_app->settings.save();
    }));
    addCheck("摸头/摸背闭眼互动", app.settings.petInteraction, G_CALLBACK(+[](GtkCheckMenuItem* item, gpointer) {
        g_app->settings.petInteraction = gtk_check_menu_item_get_active(item);
        g_app->settings.save();
    }));

    addSep();

    // Coat Skin submenu
    {
        GtkWidget* sub = gtk_menu_new();
        auto addCoat = [&](const char* lbl, CatCoatTheme c) {
            GtkWidget* it = gtk_check_menu_item_new_with_label(lbl);
            gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(it), app.settings.coatTheme == c);
            g_signal_connect(it, "activate", G_CALLBACK(+[](GtkMenuItem*, gpointer p) {
                auto coat = (CatCoatTheme)(intptr_t)p;
                g_app->settings.coatTheme = coat;
                g_app->settings.eyeTheme = coat == CatCoatTheme::Siamese ? EyeColorTheme::SiameseBlue :
                    (coat == CatCoatTheme::ClassicBlack ? EyeColorTheme::NeonChartreuse : EyeColorTheme::SoftAmber);
                g_app->settings.save();
            }), (gpointer)(intptr_t)c);
            gtk_menu_shell_append(GTK_MENU_SHELL(sub), it);
        };
        addCoat("经典小黑猫 (原版)", CatCoatTheme::ClassicBlack);
        addCoat("挖煤暹罗猫", CatCoatTheme::Siamese);
        addCoat("美短（银虎斑加白）", CatCoatTheme::Shorthair);
        addCoat("橘白猫", CatCoatTheme::OrangeWhite);
        GtkWidget* parent = gtk_menu_item_new_with_label("猫咪皮肤 🐱");
        gtk_menu_item_set_submenu(GTK_MENU_ITEM(parent), sub);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), parent);
    }

    // Keyboard Theme submenu
    {
        GtkWidget* sub = gtk_menu_new();
        auto addKb = [&](const char* lbl, KeyboardTheme t) {
            GtkWidget* it = gtk_check_menu_item_new_with_label(lbl);
            gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(it), app.settings.keyboardTheme == t);
            g_signal_connect(it, "activate", G_CALLBACK(+[](GtkMenuItem*, gpointer p) {
                g_app->settings.keyboardTheme = (KeyboardTheme)(intptr_t)p;
                g_app->settings.save();
            }), (gpointer)(intptr_t)t);
            gtk_menu_shell_append(GTK_MENU_SHELL(sub), it);
        };
        addKb("经典奶白暖黄 (原版)", KeyboardTheme::ClassicMilk);
        addKb("暗夜极客黑", KeyboardTheme::MidnightHacker);
        addKb("复古奶油灰", KeyboardTheme::RetroCream);
        GtkWidget* parent = gtk_menu_item_new_with_label("键盘配色");
        gtk_menu_item_set_submenu(GTK_MENU_ITEM(parent), sub);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), parent);
    }

    // Eye Color submenu
    {
        GtkWidget* sub = gtk_menu_new();
        auto addEye = [&](const char* lbl, EyeColorTheme e) {
            GtkWidget* it = gtk_check_menu_item_new_with_label(lbl);
            gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(it), app.settings.eyeTheme == e);
            g_signal_connect(it, "activate", G_CALLBACK(+[](GtkMenuItem*, gpointer p) {
                g_app->settings.eyeTheme = (EyeColorTheme)(intptr_t)p;
                g_app->settings.save();
            }), (gpointer)(intptr_t)e);
            gtk_menu_shell_append(GTK_MENU_SHELL(sub), it);
        };
        addEye("经典荧光黄绿 (原版)", EyeColorTheme::NeonChartreuse);
        addEye("暹罗宝石蓝", EyeColorTheme::SiameseBlue);
        addEye("琥珀金瞳", EyeColorTheme::WarmAmber);
        addEye("冰晶浅蓝", EyeColorTheme::IceCyan);
        addEye("柔和琥珀", EyeColorTheme::SoftAmber);
        addEye("淡金青绿", EyeColorTheme::ReferenceHazel);
        GtkWidget* parent = gtk_menu_item_new_with_label("瞳色切换");
        gtk_menu_item_set_submenu(GTK_MENU_ITEM(parent), sub);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), parent);
    }

    // Scale submenu
    {
        GtkWidget* sub = gtk_menu_new();
        const std::pair<const char*, int> scales[] = {
            {"迷你 (0.65x)", 65}, {"偏小 (0.85x)", 85}, {"标准 (1.0x)", 100},
            {"偏大 (1.25x)", 125}, {"超大 (1.5x)", 150}
        };
        for (auto [lbl, pct] : scales) {
            GtkWidget* it = gtk_check_menu_item_new_with_label(lbl);
            gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(it), std::fabs(app.settings.scale * 100.0f - pct) < 5.0f);
            g_signal_connect(it, "activate", G_CALLBACK(+[](GtkMenuItem*, gpointer p) {
                g_app->settings.scale = (float)(intptr_t)p / 100.0f;
                applyWindowScaleAndPos(*g_app, true);
            }), (gpointer)(intptr_t)pct);
            gtk_menu_shell_append(GTK_MENU_SHELL(sub), it);
        }
        GtkWidget* parent = gtk_menu_item_new_with_label("尺寸大小");
        gtk_menu_item_set_submenu(GTK_MENU_ITEM(parent), sub);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), parent);
    }

    addSep();
    addAction("演示打字动画", G_CALLBACK(+[](GtkMenuItem*, gpointer) {
        g_app->demoActive = true;
        g_app->demoStartTime = nowSeconds();
        g_app->demoStepIdx = 0;
    }));
    addAction("重置位置到右下角", G_CALLBACK(+[](GtkMenuItem*, gpointer) {
        g_app->settings.posX = -99999;
        g_app->settings.posY = -99999;
        applyWindowScaleAndPos(*g_app, false);
    }));
    if (!app.availableUpdateVersion.empty()) {
        std::string lbl = app.isUpdating
            ? ("⏳ 正在下载更新 " + app.availableUpdateVersion + "...")
            : ("🆕 发现新版本 " + app.availableUpdateVersion + " (点击自动更新)");
        GtkWidget* item = addAction(lbl.c_str(), G_CALLBACK(+[](GtkMenuItem*, gpointer) {
            startInAppUpdate();
        }));
        if (app.isUpdating) gtk_widget_set_sensitive(item, FALSE);
    } else {
        std::string lbl = std::string("检查更新 (当前 v") + APP_VERSION + ")";
        addAction(lbl.c_str(), G_CALLBACK(+[](GtkMenuItem*, gpointer) {
            startAsyncUpdateCheck(true, 0);
        }));
    }
    addSep();
    addAction("退出 KuroCat", G_CALLBACK(+[](GtkMenuItem*, gpointer) {
        gtk_main_quit();
    }));

    gtk_widget_show_all(menu);
    if (evt) {
        gtk_menu_popup_at_pointer(GTK_MENU(menu), (GdkEvent*)evt);
    } else {
        gtk_menu_popup_at_pointer(GTK_MENU(menu), nullptr);
    }
}

static gboolean onDraw(GtkWidget* widget, cairo_t* cr, gpointer) {
    int w = gtk_widget_get_allocated_width(widget);
    int h = gtk_widget_get_allocated_height(widget);

    cairo_save(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.0);
    cairo_paint(cr);
    cairo_restore(cr);

    cairo_save(cr);
    cairo_scale(cr, (double)w / CatPhysics::CanvasWidth, (double)h / CatPhysics::CanvasHeight);
    CatRenderer::draw(cr, g_app->physics, g_app->settings);
    cairo_restore(cr);
    return FALSE;
}

static gboolean onButtonPress(GtkWidget*, GdkEventButton* evt, gpointer) {
    if (evt->button == 3) {
        showPopupMenu(*g_app, evt);
        return TRUE;
    }
    if (evt->button == 1 && (!g_app->settings.fullClickThrough || g_app->clickThroughTemporarilyUnlocked)) {
        g_app->isDragging = true;
        g_app->dragStartRootX = evt->x_root;
        g_app->dragStartRootY = evt->y_root;
        gtk_window_get_position(GTK_WINDOW(g_app->window), &g_app->dragStartWinX, &g_app->dragStartWinY);
        return TRUE;
    }
    return FALSE;
}

static gboolean onMotionNotify(GtkWidget*, GdkEventMotion* evt, gpointer) {
    if (g_app->isDragging) {
        int nx = g_app->dragStartWinX + (int)std::round(evt->x_root - g_app->dragStartRootX);
        int ny = g_app->dragStartWinY + (int)std::round(evt->y_root - g_app->dragStartRootY);
        gtk_window_move(GTK_WINDOW(g_app->window), nx, ny);
        return TRUE;
    }
    return FALSE;
}

static gboolean onButtonRelease(GtkWidget*, GdkEventButton* evt, gpointer) {
    if (evt->button == 1 && g_app->isDragging) {
        g_app->isDragging = false;
        gtk_window_get_position(GTK_WINDOW(g_app->window), &g_app->settings.posX, &g_app->settings.posY);
        g_app->settings.save();
        return TRUE;
    }
    return FALSE;
}

static gboolean onFrameTick(gpointer) {
    if (!g_app || !g_app->isVisible) return G_SOURCE_CONTINUE;

    double now = nowSeconds();
    float dt = (float)(now - g_app->lastTickTime);
    g_app->lastTickTime = now;
    if (dt <= 0.0f || dt > 0.2f) dt = 1.0f / 60.0f;

    // Fallback GDK cursor query (for Wayland / non-X11) + Alt-key hold check
    float fbX = 0.0f, fbY = 0.0f;
    bool hasFb = false;
    bool gdkAltHeld = false;
    if (GdkDisplay* dpy = gdk_display_get_default()) {
        if (GdkSeat* seat = gdk_display_get_default_seat(dpy)) {
            if (GdkDevice* ptr = gdk_seat_get_pointer(seat)) {
                gint gx = 0, gy = 0;
                gdk_device_get_position(ptr, nullptr, &gx, &gy);
                fbX = (float)gx; fbY = (float)gy; hasFb = true;
                if (GdkWindow* gw = gtk_widget_get_window(g_app->window)) {
                    GdkModifierType mask = (GdkModifierType)0;
                    gdk_window_get_device_position(gw, ptr, nullptr, nullptr, &mask);
                    if (mask & GDK_MOD1_MASK) gdkAltHeld = true;
                }
            }
        }
    }

    g_app->input.pollAndDrain(dt, fbX, fbY, hasFb);

    // Hold Alt to temporarily unlock Full Click-Through so the user can always right-click/drag!
    bool altHeld = gdkAltHeld
        || g_app->input.activeKeys.count(PhysicalKey::LeftOption) > 0
        || g_app->input.activeKeys.count(PhysicalKey::RightOption) > 0;
    if (altHeld != g_app->clickThroughTemporarilyUnlocked) {
        g_app->clickThroughTemporarilyUnlocked = altHeld;
        if (g_app->settings.fullClickThrough) {
            updateInputShape(*g_app);
        }
    }

    if (g_app->demoActive) {
        static const PhysicalKey demoKeys[] = {
            PhysicalKey::W, PhysicalKey::A, PhysicalKey::S, PhysicalKey::D,
            PhysicalKey::F, PhysicalKey::J, PhysicalKey::O, PhysicalKey::E,
            PhysicalKey::Space, PhysicalKey::LeftShift
        };
        int targetIdx = (int)((now - g_app->demoStartTime) / 0.13);
        while (g_app->demoStepIdx <= targetIdx && g_app->demoStepIdx < 10) {
            g_app->physics.triggerKeyDown(demoKeys[g_app->demoStepIdx], g_app->settings);
            g_app->demoStepIdx++;
        }
        if (g_app->demoStepIdx >= 10) g_app->demoActive = false;
    }

    int winX = 0, winY = 0, winW = 360, winH = 320;
    gtk_window_get_position(GTK_WINDOW(g_app->window), &winX, &winY);
    gtk_window_get_size(GTK_WINDOW(g_app->window), &winW, &winH);

    // Petting detection using global cursor position (works in Smart AND Full Click-Through modes!)
    if (!g_app->isDragging && winW > 0 && winH > 0) {
        Pt cur = g_app->input.lastCursorPos;
        if (cur.x >= winX && cur.x <= winX + winW && cur.y >= winY && cur.y <= winY + winH) {
            Pt cp = {
                (cur.x - (float)winX) / (float)winW * CatPhysics::CanvasWidth,
                (cur.y - (float)winY) / (float)winH * CatPhysics::CanvasHeight
            };
            CatHitZone zone = CatRenderer::hitTest(cp, g_app->physics);
            if (zone == CatHitZone::Head || zone == CatHitZone::Body) {
                if (g_app->hasLastHover) {
                    float d = std::hypot(cp.x - g_app->lastHoverCanvas.x, cp.y - g_app->lastHoverCanvas.y);
                    if (d > 1.2f && d < 80.0f) {
                        g_app->physics.registerPetStroke(cp, d, zone == CatHitZone::Head, g_app->settings);
                    }
                }
                g_app->lastHoverCanvas = cp;
                g_app->hasLastHover = true;
            } else {
                g_app->hasLastHover = false;
            }
        } else {
            g_app->hasLastHover = false;
        }
    }

    g_app->physics.step(dt, (float)winX, (float)winY, (float)winW, g_app->input, g_app->settings);
    gtk_widget_queue_draw(g_app->drawArea);
    return G_SOURCE_CONTINUE;
}

int main(int argc, char** argv) {
    gtk_init(&argc, &argv);

    LinuxApp app;
    g_app = &app;
    app.settings.load();
    if (isAutoStartEnabled()) {
        // Keep Exec path updated if user moved portable kurocat binary
        setAutoStartEnabled(true);
    }

    app.input.onKeyDown = [&](PhysicalKey k) { app.physics.triggerKeyDown(k, app.settings); };
    app.input.onMouseClick = [&](int btn, bool down) { app.physics.triggerMouseClick(btn, down, app.settings); };
    app.input.start();

    app.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(app.window), "KuroCat");
    gtk_window_set_decorated(GTK_WINDOW(app.window), FALSE);
    gtk_window_set_skip_taskbar_hint(GTK_WINDOW(app.window), TRUE);
    gtk_window_set_skip_pager_hint(GTK_WINDOW(app.window), TRUE);
    gtk_window_set_accept_focus(GTK_WINDOW(app.window), FALSE);
    gtk_window_set_type_hint(GTK_WINDOW(app.window), GDK_WINDOW_TYPE_HINT_UTILITY);
    gtk_window_stick(GTK_WINDOW(app.window));
    gtk_widget_set_app_paintable(app.window, TRUE);

    GdkScreen* screen = gtk_widget_get_screen(app.window);
    if (GdkVisual* visual = gdk_screen_get_rgba_visual(screen)) {
        gtk_widget_set_visual(app.window, visual);
    }

    app.drawArea = gtk_drawing_area_new();
    gtk_container_add(GTK_CONTAINER(app.window), app.drawArea);

    gtk_widget_add_events(app.window, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK);
    g_signal_connect(app.drawArea, "draw", G_CALLBACK(onDraw), nullptr);
    g_signal_connect(app.window, "button-press-event", G_CALLBACK(onButtonPress), nullptr);
    g_signal_connect(app.window, "motion-notify-event", G_CALLBACK(onMotionNotify), nullptr);
    g_signal_connect(app.window, "button-release-event", G_CALLBACK(onButtonRelease), nullptr);
    g_signal_connect(app.window, "destroy", G_CALLBACK(gtk_main_quit), nullptr);
    g_signal_connect(app.window, "realize", G_CALLBACK(+[](GtkWidget* w, gpointer) {
        updateInputShape(*g_app);
        if (GdkWindow* gw = gtk_widget_get_window(w)) {
            GdkCursor* hand = gdk_cursor_new_from_name(gdk_window_get_display(gw), "grab");
            if (hand) {
                gdk_window_set_cursor(gw, hand);
                g_object_unref(hand);
            }
        }
    }), nullptr);

    // System tray icon (works cleanly on 统信 UOS, Deepin, KDE, XFCE, MATE!)
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    if (GdkPixbuf* pb = createCatTrayPixbuf()) {
        app.trayIcon = gtk_status_icon_new_from_pixbuf(pb);
        gtk_status_icon_set_tooltip_text(app.trayIcon, "KuroCat 黑猫键盘桌宠 (右键设置)");
        g_signal_connect(app.trayIcon, "popup-menu", G_CALLBACK(+[](GtkStatusIcon*, guint, guint, gpointer) {
            showPopupMenu(*g_app, nullptr);
        }), nullptr);
        g_signal_connect(app.trayIcon, "activate", G_CALLBACK(+[](GtkStatusIcon*, gpointer) {
            showPopupMenu(*g_app, nullptr);
        }), nullptr);
        g_object_unref(pb);
    }
    G_GNUC_END_IGNORE_DEPRECATIONS

    applyWindowScaleAndPos(app, false);
    gtk_widget_show_all(app.window);

    app.lastTickTime = nowSeconds();
    g_timeout_add(16, onFrameTick, nullptr);
    startAsyncUpdateCheck(false, 2500);

    gtk_main();
    app.input.stop();
    return 0;
}
