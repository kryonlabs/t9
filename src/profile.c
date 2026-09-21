#include "profile.h"

int profile_color_to_terminal_rgb(Color color)
{
    return TerminalPaneColorToRGB(color);
}

static TerminalPaneColors terminal_profile_theme(const Palette *palette)
{
    TerminalPaneColors colors;

    if(palette == NULL)
        return ResolveTerminalPaneThemeColors(GetTerminalPaneThemeColors());
    colors.background = palette->terminal_background;
    colors.text = palette->foreground;
    colors.muted_text = palette->muted;
    colors.selection = palette->selection;
    colors.selection_text = palette->selection_text;
    colors.cursor = palette->cursor;
    colors.link = palette->link;
    colors.border = palette->chrome_border;
    colors.scroll_indicator = palette->scroll_indicator;
    colors.scroll_indicator_text = palette->scroll_indicator_text;
    colors.bell_overlay = palette->bell_overlay;
    colors.bell_border = palette->bell_border;
    return ResolveTerminalPaneThemeColors(colors);
}

static TerminalPaneProfileColors terminal_profile_configured(
    const Config *config)
{
    TerminalPaneProfileColors colors;

    colors.foreground = COLOR_DEFAULT;
    colors.background = COLOR_DEFAULT;
    colors.cursor = COLOR_DEFAULT;
    colors.selection_foreground = COLOR_DEFAULT;
    colors.selection_background = COLOR_DEFAULT;
    if(config == NULL)
        return colors;
    colors.foreground = config->terminal_foreground;
    colors.background = config->terminal_background;
    colors.cursor = config->terminal_cursor;
    colors.selection_foreground = config->terminal_selection_foreground;
    colors.selection_background = config->terminal_selection_background;
    return colors;
}

static TerminalPaneProfileState terminal_profile_state(
    const TerminalState *terminal)
{
    TerminalPaneProfileState state;

    state.base_foreground = COLOR_DEFAULT;
    state.base_background = COLOR_DEFAULT;
    state.base_cursor = COLOR_DEFAULT;
    state.base_selection_foreground = COLOR_DEFAULT;
    state.base_selection_background = COLOR_DEFAULT;
    state.foreground = COLOR_DEFAULT;
    state.background = COLOR_DEFAULT;
    state.cursor = COLOR_DEFAULT;
    state.selection_foreground = COLOR_DEFAULT;
    state.selection_background = COLOR_DEFAULT;
    if(terminal == NULL)
        return state;
    state.base_foreground = terminal->base_fg;
    state.base_background = terminal->base_bg;
    state.base_cursor = terminal->base_cursor_color;
    state.base_selection_foreground = terminal->base_selection_fg;
    state.base_selection_background = terminal->base_selection_bg;
    state.foreground = terminal->default_fg;
    state.background = terminal->default_bg;
    state.cursor = terminal->cursor_color;
    state.selection_foreground = terminal->selection_fg;
    state.selection_background = terminal->selection_bg;
    return state;
}

static void terminal_apply_profile_state(
    TerminalState *terminal, TerminalPaneProfileState state)
{
    if(terminal == NULL)
        return;
    terminal->base_fg = state.base_foreground;
    terminal->base_bg = state.base_background;
    terminal->base_cursor_color = state.base_cursor;
    terminal->base_selection_fg = state.base_selection_foreground;
    terminal->base_selection_bg = state.base_selection_background;
    terminal->default_fg = state.foreground;
    terminal->default_bg = state.background;
    terminal->cursor_color = state.cursor;
    terminal->selection_fg = state.selection_foreground;
    terminal->selection_bg = state.selection_background;
}

TerminalProfileColors terminal_profile_colors(const Config *config,
                                              const Palette *palette)
{
    return ResolveTerminalPaneProfileColors(
        terminal_profile_configured(config), terminal_profile_theme(palette));
}

void terminal_profile_apply_new(const Config *config, const Palette *palette,
                                TerminalState *terminal)
{
    TerminalPaneProfileState state;

    if(terminal == NULL)
        return;
    state = terminal_profile_state(terminal);
    TerminalPaneProfileStateApplyNew(&state,
                                     terminal_profile_colors(config, palette));
    terminal_apply_profile_state(terminal, state);
}

void terminal_profile_seed_missing(const Config *config,
                                   const Palette *palette,
                                   TerminalState *terminal)
{
    TerminalPaneProfileState state;

    if(terminal == NULL)
        return;
    state = terminal_profile_state(terminal);
    TerminalPaneProfileStateSeedMissing(&state,
                                        terminal_profile_colors(config, palette));
    terminal_apply_profile_state(terminal, state);
}

void terminal_profile_sync_changed(TerminalState *terminal,
                                   TerminalProfileColors old_colors,
                                   TerminalProfileColors new_colors)
{
    TerminalPaneProfileState state;

    if(terminal == NULL)
        return;
    state = terminal_profile_state(terminal);
    TerminalPaneProfileStateSyncChanged(&state, old_colors, new_colors);
    terminal_apply_profile_state(terminal, state);
}
