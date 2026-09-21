#include "app_terminal_view.h"

#include "app_chrome.h"
#include "app_context_menu.h"
#include "app_menu.h"
#include "app_profile.h"
#include "app_search.h"
#include "app_sessions.h"
#include "selection.h"
#include "terminal.h"

#include <stdio.h>
#include <string.h>

static int max_int(int a, int b)
{
    return a > b ? a : b;
}

static int clamp_int(int value, int low, int high)
{
    if(value < low)
        return low;
    if(value > high)
        return high;
    return value;
}

static Color blend_color(Color a, Color b, float t)
{
    Color out;

    if(t < 0.0f)
        t = 0.0f;
    if(t > 1.0f)
        t = 1.0f;
    out.r = (unsigned char)((float)a.r + ((float)b.r - (float)a.r) * t);
    out.g = (unsigned char)((float)a.g + ((float)b.g - (float)a.g) * t);
    out.b = (unsigned char)((float)a.b + ((float)b.b - (float)a.b) * t);
    out.a = a.a;
    return out;
}

static Color
opaque_color(Color color)
{
    color.a = 255;
    return color;
}

static Color alpha_color(Color color, int opacity)
{
    opacity = clamp_int(opacity, 0, 100);
    color.a = (unsigned char)(opacity * 255 / 100);
    return color;
}

static void release_background_texture(State *app)
{
    if(app == NULL)
        return;
    if(app->background_texture.id != 0)
        UnloadTexture(app->background_texture);
    memset(&app->background_texture, 0, sizeof(app->background_texture));
    app->background_texture_path[0] = '\0';
}

void release_terminal_view_resources(State *app)
{
    release_background_texture(app);
}

static void sync_background_texture(State *app)
{
    if(app == NULL)
        return;
    if(strcmp(app->background_texture_path,
              app->config.background_image) == 0)
        return;
    release_background_texture(app);
    if(app->config.background_image[0] == '\0')
        return;
    app->background_texture = LoadTexture(app->config.background_image);
    if(app->background_texture.id != 0)
        snprintf(app->background_texture_path,
                 sizeof(app->background_texture_path), "%s",
                 app->config.background_image);
}

static void draw_background_texture(State *app, Rectangle viewport)
{
    Texture2D texture;
    float scale;
    float w;
    float h;
    Rectangle dst;
    Rectangle src;
    Vector2 origin;

    if(app == NULL)
        return;
    sync_background_texture(app);
    texture = app->background_texture;
    if(texture.id == 0 || texture.width <= 0 || texture.height <= 0)
        return;
    scale = viewport.width / (float)texture.width;
    if((float)texture.height * scale < viewport.height)
        scale = viewport.height / (float)texture.height;
    w = (float)texture.width * scale;
    h = (float)texture.height * scale;
    dst.x = viewport.x + (viewport.width - w) * 0.5f;
    dst.y = viewport.y + (viewport.height - h) * 0.5f;
    dst.width = w;
    dst.height = h;
    BeginScissorMode((int)viewport.x, (int)viewport.y,
                     (int)viewport.width, (int)viewport.height);
    src.x = 0.0f;
    src.y = 0.0f;
    src.width = (float)texture.width;
    src.height = (float)texture.height;
    origin.x = 0.0f;
    origin.y = 0.0f;
    DrawTexturePro(texture, src, dst, origin, 0.0f, WHITE);
    EndScissorMode();
}

static void draw_tabs(State *app, Rectangle bounds)
{
    Tab tabs[MAX_SESSIONS];
    int i;
    int count;
    int clicked;
    int closed = -1;
    int middle_clicked = -1;
    int double_clicked = -1;
    int reordered_from = -1;
    int reordered_to = -1;
    Rectangle selected_bounds = {0.0f, 0.0f, 0.0f, 0.0f};
    TabBarProps bar_props;

    if(app == NULL || !app_tab_bar_visible(app))
        return;
    memset(tabs, 0, sizeof(tabs));
    for(i = 0; i < app->session_count; i++) {
        tabs[i].label = session_title(&app->sessions[i]);
        tabs[i].closeable = app->session_count > 1;
    }
    count = app->session_count;
    memset(&bar_props, 0, sizeof(bar_props));
    bar_props.bounds = bounds;
    bar_props.tabs = tabs;
    bar_props.count = count;
    bar_props.selected_index = app->active;
    bar_props.min_tab_width = Scale(72);
    bar_props.max_tab_width = Scale(280);
    bar_props.scroll_offset = &app->tab_scroll;
    bar_props.focus_selected = true;
    bar_props.closed_index = &closed;
    bar_props.double_clicked_index = &double_clicked;
    bar_props.reordered_from_index = &reordered_from;
    bar_props.reordered_to_index = &reordered_to;
    bar_props.selected_tab_bounds = &selected_bounds;
    bar_props.middle_clicked_index = &middle_clicked;
    clicked = TabBar(bar_props);
    if(reordered_from >= 0 && reordered_from < app->session_count &&
       reordered_to >= 0 && reordered_to < app->session_count) {
        move_session(app, reordered_from, reordered_to);
        return;
    }
    if(middle_clicked >= 0 && middle_clicked < app->session_count &&
       app->config.middle_click_closes_tab) {
        close_session(app, middle_clicked);
        return;
    }
    if(closed >= 0 && closed < app->session_count) {
        close_session(app, closed);
        return;
    }
    if(double_clicked >= 0 && double_clicked < app->session_count) {
        const char *title = session_title(&app->sessions[double_clicked]);

        app->rename_index = double_clicked;
        snprintf(app->rename_text, sizeof(app->rename_text), "%s", title);
        app->rename_cursor = (int)strlen(app->rename_text);
        app->rename_focused = 1;
        app->rename_anchor = selected_bounds;
        set_active_session(app, double_clicked);
        return;
    }
    if(clicked >= 0) {
        if(clicked < app->session_count)
            set_active_session(app, clicked);
    }
}

static int cell_text(const Cell *cell, char *text, int text_size)
{
    int len = 0;
    unsigned int codepoint;

    if(cell == NULL)
        return 0;
    codepoint = cell->codepoint;
    if(text == NULL || text_size < 2 || codepoint == 0 || codepoint == ' ') {
        if(text != NULL && text_size > 0)
            text[0] = '\0';
        return 0;
    }
    if(!AppendTerminalPaneUTF8Codepoint(text, text_size, &len, codepoint))
        return 0;
    if(cell->combining != 0)
        AppendTerminalPaneUTF8Codepoint(text, text_size, &len,
                                        cell->combining);
    text[len] = '\0';
    return len;
}

static Color resolve_terminal_color(const State *app,
                                    const TerminalState *terminal, int value,
                                    Color fallback)
{
    if(app == NULL)
        return fallback;
    return ResolveTerminalPaneColorWithOverrides(
        &app->palette.terminal_palette,
        terminal != NULL ? terminal->palette_overrides : NULL, value,
        fallback);
}

static TerminalPaneColors terminal_theme_tokens(void)
{
    return ResolveTerminalPaneThemeColors(GetTerminalPaneThemeColors());
}

static TerminalPaneViewColors terminal_view_colors(
    const State *app, const TerminalState *terminal,
    TerminalPaneColors theme_colors)
{
    TerminalPaneProfileColors colors = {
        COLOR_DEFAULT,
        COLOR_DEFAULT,
        COLOR_DEFAULT,
        COLOR_DEFAULT,
        COLOR_DEFAULT
    };

    if(terminal != NULL) {
        colors.foreground = terminal->default_fg;
        colors.background = terminal->default_bg;
        colors.cursor = terminal->cursor_color;
        colors.selection_foreground = terminal->selection_fg;
        colors.selection_background = terminal->selection_bg;
    }
    return ResolveTerminalPaneViewColors(
        app != NULL ? &app->palette.terminal_palette : NULL,
        terminal != NULL ? terminal->palette_overrides : NULL, colors,
        theme_colors);
}

static void draw_line_cells(State *app, const TerminalState *terminal,
                            TerminalPaneViewColors view_colors,
                            TerminalPaneColors theme_colors,
                            int visible_row, int y)
{
    int col;
    Vector2 text_pos;

    if(terminal == NULL || visible_row < 0 ||
       visible_row >= terminal_visible_line_count(terminal))
        return;
    for(col = 0; col < terminal->cols; col++) {
        const Cell *cell = terminal_visible_cell(terminal, col, visible_row);
        char text[16];
        int len = 0;
        Color fg;
        Color bg;
        Color underline;
        int linked;
        int selected = selection_contains(&app->selection, visible_row, col);

        if(cell == NULL)
            continue;
        if((cell->style & STYLE_WIDE_CONT) != 0)
            continue;
        fg = resolve_terminal_color(app, terminal, cell->fg,
                                    view_colors.foreground);
        bg = resolve_terminal_color(app, terminal, cell->bg,
                                    view_colors.background);
        underline = resolve_terminal_color(app, terminal, cell->underline, fg);
        linked = cell->hyperlink > 0;
        if(linked)
            fg = theme_colors.link;
        if((cell->style & STYLE_INVERSE) != 0) {
            Color tmp = fg;

            fg = bg;
            bg = tmp;
        }
        if((cell->style & STYLE_FAINT) != 0)
            fg = blend_color(fg, bg, 0.45f);
        if(selected) {
            DrawRectangle((int)app->viewport.x + col * app->cell_w, y,
                          app->cell_w, app->line_h,
                          view_colors.selection_background);
            fg = view_colors.selection_foreground;
            underline = view_colors.selection_foreground;
        } else if(cell->bg != COLOR_DEFAULT ||
                  (cell->style & STYLE_INVERSE) != 0) {
            DrawRectangle((int)app->viewport.x + col * app->cell_w, y,
                          app->cell_w, app->line_h, bg);
        }
        if(cell->codepoint == 0 || cell->codepoint == ' ')
            continue;
        if((cell->style & STYLE_CONCEAL) != 0)
            continue;
        if((cell->style & STYLE_BLINK) != 0 &&
           ((int)(GetTime() * 2.0) & 1) != 0)
            continue;
        len = cell_text(cell, text, sizeof(text));
        if(len <= 0)
            continue;
        text_pos.x = app->viewport.x + col * app->cell_w;
        text_pos.y = (float)y;
        DrawTextEx(GetTextFont(), text, text_pos,
                   (float)app->config.font_size, 0.0f, fg);
        if(app->config.allow_bold && (cell->style & STYLE_BOLD) != 0) {
            text_pos.x = app->viewport.x + col * app->cell_w + 1;
            DrawTextEx(GetTextFont(), text, text_pos,
                       (float)app->config.font_size, 0.0f, fg);
        }
        if(linked && !selected)
            underline = theme_colors.link;
        if((cell->style & STYLE_UNDERLINE) != 0 || linked)
            DrawRectangle((int)app->viewport.x + col * app->cell_w,
                          y + app->line_h - 3, app->cell_w, 1, underline);
        if((cell->style & STYLE_OVERLINE) != 0)
            DrawRectangle((int)app->viewport.x + col * app->cell_w,
                          y + 1, app->cell_w, 1, underline);
    }
}

static void draw_sixel_images(State *app, const TerminalState *terminal,
                              TerminalPaneViewColors view_colors)
{
    int i;

    if(app == NULL || terminal == NULL)
        return;
    for(i = 0; i < terminal_sixel_count(terminal); i++) {
        const SixelImage *image = terminal_sixel_image(terminal, i);
        int visible_row;
        int origin_x;
        int origin_y;
        int y;
        float pixel_w;
        float pixel_h;

        if(image == NULL || image->pixels == NULL ||
           image->alternate_screen != terminal->alternate_screen)
            continue;
        pixel_h = (float)app->line_h / 6.0f;
        pixel_w = (float)app->cell_w / 6.0f;
        if(image->pixel_aspect_num > 0 && image->pixel_aspect_den > 0)
            pixel_w *= (float)image->pixel_aspect_num /
                       (float)image->pixel_aspect_den;
        if(pixel_w <= 0.0f)
            pixel_w = (float)app->cell_w / 6.0f;
        if(pixel_h <= 0.0f)
            pixel_h = 1.0f;
        visible_row =
            terminal->alternate_screen ? image->row
                                       : terminal->scrollback_count + image->row;
        origin_x = (int)app->viewport.x + image->col * app->cell_w;
        origin_y = (int)app->viewport.y +
                   (visible_row - app->first_visible_row) * app->line_h;
        for(y = 0; y < image->height; y++) {
            float dest_y = (float)origin_y + (float)y * pixel_h;
            int x = 0;

            if(dest_y + pixel_h <= app->viewport.y ||
               dest_y >= app->viewport.y + app->viewport.height)
                continue;
            while(x < image->width) {
                int pixel = image->pixels[y * image->width + x];
                int run = 1;
                Color color;

                if(pixel == COLOR_DEFAULT) {
                    x++;
                    continue;
                }
                while(x + run < image->width &&
                      image->pixels[y * image->width + x + run] == pixel)
                    run++;
                if((float)origin_x + ((float)x + (float)run) * pixel_w >
                       app->viewport.x &&
                   (float)origin_x + (float)x * pixel_w <
                       app->viewport.x + app->viewport.width) {
                    Rectangle pixel_run;

                    color = resolve_terminal_color(app, terminal, pixel,
                                                   view_colors.foreground);
                    pixel_run.x = (float)origin_x + (float)x * pixel_w;
                    pixel_run.y = dest_y;
                    pixel_run.width = (float)run * pixel_w;
                    pixel_run.height = pixel_h;
                    DrawRectangleRec(pixel_run, color);
                }
                x += run;
            }
        }
    }
}

void draw_terminal_view(State *app, Session *session, Rectangle bounds)
{
    TerminalState *terminal = &session->terminal;
    int menu_h = app_menu_bar_height(app);
    int tab_h = app_tab_bar_height(app);
    int chrome_h = menu_h + tab_h;
    TerminalPaneMetrics metrics;
    TerminalPaneColors theme_colors;
    TerminalPaneViewColors view_colors;
    int total_rows;
    int row;
    int max_scroll;
    Rectangle chrome;
    Vector2 cursor_pos;
    ModalProps modal_props;
    TerminalPaneScrollIndicator scroll_props;

    seed_theme_defaults_to_terminal(app, terminal);
    UseTextFont("t9-terminal");
    metrics = MeasureTerminalPaneContent(
        TerminalPaneContentBounds(bounds, chrome_h, 0), app->config.font_size);
    app->cell_w = metrics.cell_width;
    app->line_h = metrics.line_height;
    app->viewport = metrics.content;
    app->visible_rows = metrics.rows;
    UseTextFont("t9-ui");
    terminal_resize(terminal, metrics.cols, metrics.rows);

    total_rows = terminal_visible_line_count(terminal);
    max_scroll = max_int(0, total_rows - app->visible_rows);
    session->scroll_offset = clamp_int(session->scroll_offset, 0, max_scroll);
    app->first_visible_row = selection_first_visible_row(
        total_rows, app->visible_rows, session->scroll_offset);
    theme_colors = terminal_theme_tokens();
    view_colors = terminal_view_colors(app, terminal, theme_colors);

    DrawRectangleRec(bounds, opaque_color(app->palette.background));
    if(menu_h > 0) {
        chrome.x = bounds.x;
        chrome.y = bounds.y;
        chrome.width = bounds.width;
        chrome.height = (float)menu_h;
        draw_app_menu_bar(app, chrome);
    }
    if(tab_h > 0) {
        chrome.x = bounds.x;
        chrome.y = bounds.y + (float)menu_h;
        chrome.width = bounds.width;
        chrome.height = (float)tab_h;
        draw_tabs(app, chrome);
    }
    draw_background_texture(app, app->viewport);
    DrawRectangleRec(app->viewport,
                     alpha_color(view_colors.background,
                                 app->config.background_opacity));

    BeginScissorMode((int)app->viewport.x, (int)app->viewport.y,
                     (int)app->viewport.width, (int)app->viewport.height);
    draw_sixel_images(app, terminal, view_colors);
    UseTextFont("t9-terminal");
    for(row = 0; row < app->visible_rows; row++) {
        int visible_row = app->first_visible_row + row;
        int y = (int)app->viewport.y + row * app->line_h;

        draw_line_cells(app, terminal, view_colors, theme_colors, visible_row,
                        y);
    }
    if(terminal->cursor_visible && session->scroll_offset == 0 &&
       (!terminal->cursor_blink || ((int)(GetTime() * 2.0) & 1) == 0)) {
        int cursor_visible_row =
            terminal->alternate_screen
                ? terminal->cursor_row
                : terminal->scrollback_count + terminal->cursor_row;
        int cursor_y = cursor_visible_row - app->first_visible_row;

        if(cursor_y >= 0 && cursor_y < app->visible_rows) {
            int x = (int)app->viewport.x + terminal->cursor_col * app->cell_w;
            int y = (int)app->viewport.y + cursor_y * app->line_h;
            int style = terminal->cursor_style != TERMINAL_CURSOR_DEFAULT
                            ? terminal->cursor_style
                            : app->config.cursor_style;

            if(style == TERMINAL_CURSOR_BAR) {
                DrawRectangle(x, y, 2, app->line_h, view_colors.cursor);
            } else if(style == TERMINAL_CURSOR_UNDERLINE) {
                DrawRectangle(x, y + app->line_h - 3, app->cell_w, 2,
                              view_colors.cursor);
            } else {
                const Cell *cell =
                    terminal_cell(terminal, terminal->cursor_col,
                                  terminal->cursor_row);
                char text[16];

                DrawRectangle(x, y, app->cell_w, app->line_h,
                              view_colors.cursor);
                if(cell != NULL && cell_text(cell, text, sizeof(text)) > 0) {
                    cursor_pos.x = (float)x;
                    cursor_pos.y = (float)y;
                    DrawTextEx(GetTextFont(), text, cursor_pos,
                               (float)app->config.font_size, 0.0f,
                               view_colors.background);
                }
            }
        }
    }
    UseTextFont("t9-ui");
    EndScissorMode();

    if(app->bell_until > GetTime()) {
        float alpha = (float)((app->bell_until - GetTime()) / 0.18);
        Color overlay = theme_colors.bell_overlay;
        Color border = theme_colors.bell_border;

        alpha = alpha < 0.0f ? 0.0f : alpha;
        alpha = alpha > 1.0f ? 1.0f : alpha;
        overlay.a = (unsigned char)((float)overlay.a * alpha);
        border.a = (unsigned char)((float)border.a * alpha);
        DrawRectangleRec(app->viewport, overlay);
        DrawRectangleLines((int)app->viewport.x, (int)app->viewport.y,
                           (int)app->viewport.width, (int)app->viewport.height,
                           border);
    }

    if(session->scroll_offset > 0) {
        scroll_props.viewport = app->viewport;
        scroll_props.scroll_offset = session->scroll_offset;
        scroll_props.font_size = Scale(13);
        scroll_props.colors = theme_colors;
        DrawTerminalPaneScrollIndicator(scroll_props);
    }
    draw_context_menu(app, session);
    if(app->about_visible) {
        static const ModalAction actions[] = {{.label = "OK"}};

        memset(&modal_props, 0, sizeof(modal_props));
        modal_props.title = "Terminal";
        modal_props.message = "A Kryon terminal application.";
        modal_props.actions = actions;
        modal_props.action_count = 1;
        if(Modal(modal_props) != 0)
            app->about_visible = 0;
    }
    draw_search_prompt(app);
    if(app->profile_prompt != PROFILE_PROMPT_NONE) {
        static const ModalAction actions[] = {
            {.label = "Cancel"},
            {.label = "Save"}
        };
        int result;

        memset(&modal_props, 0, sizeof(modal_props));
        modal_props.title = profile_prompt_title(app->profile_prompt);
        modal_props.actions = actions;
        modal_props.action_count = 2;
        modal_props.text = app->profile_text;
        modal_props.text_size = (int)sizeof(app->profile_text);
        modal_props.cursor_position = &app->profile_cursor;
        modal_props.focused = &app->profile_focused;
        result = Modal(modal_props);

        if(result == 1) {
            app->profile_prompt = PROFILE_PROMPT_NONE;
            app->profile_focused = 0;
        } else if(result == 2) {
            apply_profile_prompt(app);
            app->profile_prompt = PROFILE_PROMPT_NONE;
            app->profile_focused = 0;
        }
    }
    if(app->rename_index >= 0 && app->rename_index < app->session_count) {
        static const ModalAction actions[] = {
            {.label = "Cancel"},
            {.label = "Rename"}
        };
        int result;

        memset(&modal_props, 0, sizeof(modal_props));
        modal_props.title = "Title";
        modal_props.actions = actions;
        modal_props.action_count = 2;
        modal_props.text = app->rename_text;
        modal_props.text_size = (int)sizeof(app->rename_text);
        modal_props.cursor_position = &app->rename_cursor;
        modal_props.focused = &app->rename_focused;
        modal_props.focus_id = 9301;
        modal_props.max_width = 300;
        result = Modal(modal_props);

        if(result == 1) {
            app->rename_index = -1;
            app->rename_focused = 0;
        } else if(result == 2) {
            session_set_title(&app->sessions[app->rename_index],
                              app->rename_text);
            app->rename_index = -1;
            app->rename_focused = 0;
        }
    } else if(app->rename_index >= 0) {
        app->rename_index = -1;
        app->rename_focused = 0;
    }
}

void draw_starting_frame(State *app)
{
    Rectangle bounds = {0, 0, (float)GetScreenWidth(), (float)GetScreenHeight()};
    int menu_h = app_menu_bar_height(app);
    int tab_h = app_tab_bar_height(app);
    Rectangle viewport = TerminalPaneContentBounds(bounds, menu_h + tab_h, 0);
    TerminalPaneColors theme_colors = terminal_theme_tokens();
    Rectangle chrome;
    TextProps text_props;

    UseTextFont("t9-ui");
    DrawRectangleRec(bounds, opaque_color(app->palette.background));
    if(menu_h > 0) {
        chrome.x = bounds.x;
        chrome.y = bounds.y;
        chrome.width = bounds.width;
        chrome.height = (float)menu_h;
        draw_app_menu_bar(app, chrome);
    }
    if(tab_h > 0) {
        chrome.x = bounds.x;
        chrome.y = bounds.y + (float)menu_h;
        chrome.width = bounds.width;
        chrome.height = (float)tab_h;
        draw_tabs(app, chrome);
    }
    draw_background_texture(app, viewport);
    DrawRectangleRec(viewport,
                     alpha_color(theme_colors.background,
                                 app->config.background_opacity));
    memset(&text_props, 0, sizeof(text_props));
    text_props.bounds.x = viewport.x + 10;
    text_props.bounds.y = viewport.y + 10;
    text_props.bounds.width = viewport.width - 20;
    text_props.bounds.height = (float)Scale(24);
    text_props.text = "Starting terminal...";
    text_props.font = app->config.font_size;
    text_props.wrap = TextWrapNone;
    Text(text_props);
}
