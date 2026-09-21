#include "terminal_pane_metrics.h"

static float
terminal_pane_scale(float scale)
{
    if(scale <= 0.0f)
        return 1.0f;
    return scale;
}

static int
terminal_pane_px(float value, float scale)
{
    return (int)(value * terminal_pane_scale(scale));
}

TerminalPaneMetricsPolicy
TerminalPaneMetricsPolicyFor(float scale)
{
    TerminalPaneMetricsPolicy policy = {0};

    policy.font_size = terminal_pane_px(13.0f, scale);
    policy.line_gap = terminal_pane_px(2.0f, scale);
    policy.padding = terminal_pane_px(6.0f, scale);
    policy.min_cols = 8;
    policy.min_rows = 4;
    return policy;
}

int
TerminalPaneFontSizeFor(int requested_font_size,
                        TerminalPaneMetricsPolicy policy)
{
    if(requested_font_size > 0)
        return requested_font_size;
    return policy.font_size;
}

int
TerminalPaneLineHeightFor(int measured_line_height, int font_size,
                          TerminalPaneMetricsPolicy policy)
{
    int min_height = font_size + policy.line_gap;

    if(measured_line_height < min_height)
        return min_height;
    return measured_line_height;
}

int
TerminalPanePaddingFor(int requested_padding,
                       TerminalPaneMetricsPolicy policy)
{
    if(requested_padding >= 0)
        return requested_padding;
    return policy.padding;
}

Rectangle
TerminalPaneContentBoundsFor(Rectangle bounds, int top_inset, int padding)
{
    Rectangle content = {0};

    if(top_inset < 0)
        top_inset = 0;
    if(padding < 0)
        padding = 0;
    content.x = bounds.x + (float)padding;
    content.y = bounds.y + (float)(top_inset + padding);
    content.width = bounds.width - (float)(padding * 2);
    content.height = bounds.height - (float)(top_inset + padding * 2);
    if(content.width < 0.0f)
        content.width = 0.0f;
    if(content.height < 0.0f)
        content.height = 0.0f;
    return content;
}

int
TerminalPaneClampCols(int cols, int max_cols, TerminalPaneMetricsPolicy policy)
{
    if(cols < policy.min_cols)
        cols = policy.min_cols;
    if(max_cols > 0 && cols > max_cols)
        cols = max_cols;
    return cols;
}

int
TerminalPaneClampRows(int rows, int max_rows, TerminalPaneMetricsPolicy policy)
{
    if(rows < policy.min_rows)
        rows = policy.min_rows;
    if(max_rows > 0 && rows > max_rows)
        rows = max_rows;
    return rows;
}

TerminalPaneScrollIndicatorMetrics
TerminalPaneScrollIndicatorMetricsFor(float scale)
{
    TerminalPaneScrollIndicatorMetrics metrics = {0};

    metrics.font_size = terminal_pane_px(13.0f, scale);
    metrics.right_offset = terminal_pane_px(16.0f, scale);
    metrics.top_offset = terminal_pane_px(6.0f, scale);
    metrics.width_pad = terminal_pane_px(10.0f, scale);
    metrics.height = terminal_pane_px(22.0f, scale);
    metrics.text_x = terminal_pane_px(5.0f, scale);
    metrics.text_y = terminal_pane_px(4.0f, scale);
    return metrics;
}

Rectangle
TerminalPaneScrollIndicatorBoundsFor(Rectangle viewport, int label_width,
                                     TerminalPaneScrollIndicatorMetrics metrics)
{
    Rectangle badge = {0};

    if(viewport.width <= 0.0f || viewport.height <= 0.0f || label_width <= 0)
        return badge;
    badge.x = viewport.x + viewport.width - (float)label_width -
              (float)metrics.right_offset;
    badge.y = viewport.y + (float)metrics.top_offset;
    badge.width = (float)(label_width + metrics.width_pad);
    badge.height = (float)metrics.height;
    if(badge.x < viewport.x)
        badge.x = viewport.x;
    if(badge.width > viewport.width)
        badge.width = viewport.width;
    return badge;
}
