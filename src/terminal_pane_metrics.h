#ifndef KAPSULE_TERMINAL_PANE_METRICS_H
#define KAPSULE_TERMINAL_PANE_METRICS_H

/* t9-local port of the metrics policy kryon's runtime/terminal_pane module
 * provided before the engine moved into this repository. */

#include "kryon_compat.generated.h"

typedef struct TerminalPaneMetricsPolicy {
    int font_size;
    int line_gap;
    int padding;
    int min_cols;
    int min_rows;
} TerminalPaneMetricsPolicy;

typedef struct TerminalPaneScrollIndicatorMetrics {
    int font_size;
    int right_offset;
    int top_offset;
    int width_pad;
    int height;
    int text_x;
    int text_y;
} TerminalPaneScrollIndicatorMetrics;

TerminalPaneMetricsPolicy TerminalPaneMetricsPolicyFor(float scale);
int TerminalPaneFontSizeFor(int requested_font_size,
                            TerminalPaneMetricsPolicy policy);
int TerminalPaneLineHeightFor(int measured_line_height, int font_size,
                              TerminalPaneMetricsPolicy policy);
int TerminalPanePaddingFor(int requested_padding,
                           TerminalPaneMetricsPolicy policy);
Rectangle TerminalPaneContentBoundsFor(Rectangle bounds, int top_inset,
                                       int padding);
int TerminalPaneClampCols(int cols, int max_cols,
                          TerminalPaneMetricsPolicy policy);
int TerminalPaneClampRows(int rows, int max_rows,
                          TerminalPaneMetricsPolicy policy);
TerminalPaneScrollIndicatorMetrics
TerminalPaneScrollIndicatorMetricsFor(float scale);
Rectangle TerminalPaneScrollIndicatorBoundsFor(Rectangle viewport,
                                               int label_width,
                                               TerminalPaneScrollIndicatorMetrics metrics);

#endif
