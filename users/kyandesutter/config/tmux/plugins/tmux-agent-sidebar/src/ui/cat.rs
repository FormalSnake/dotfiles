use ratatui::{
    Frame,
    layout::Rect,
    style::{Color, Style},
    text::{Line, Span},
};
use unicode_width::UnicodeWidthStr;

use crate::state::AppState;

/// Cat animation state machine.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CatState {
    Idle,
    WalkRight,
    Working,
    WalkLeft,
}

pub const CAT_WIDTH: u16 = 7;
pub const CAT_HOME_X: u16 = 1;
pub const DESK_OFFSET: u16 = 10;
pub const DESK_WIDTH: u16 = 5;
pub const MAX_PAPER_HEIGHT: u16 = 3;
/// Ticks between idle bobs (~2 seconds at 200ms tick).
pub const BOB_INTERVAL: usize = 10;
const CAT_BODY: Color = Color::Indexed(208);
const CAT_EYE: Color = Color::Indexed(114);
const CAT_NOSE: Color = Color::Indexed(174);

fn sitting_sprite() -> Vec<Line<'static>> {
    vec![
        Line::from(vec![
            Span::raw(" "),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::raw(" "),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::raw("  "),
        ]),
        Line::from(vec![
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::styled("▀", Style::new().fg(CAT_EYE)),
            Span::styled("▀", Style::new().fg(CAT_NOSE)),
            Span::styled("▀", Style::new().fg(CAT_EYE)),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::raw(" "),
        ]),
        Line::from(vec![
            Span::raw(" "),
            Span::styled("▀", Style::new().fg(CAT_BODY)),
            Span::raw(" "),
            Span::styled("▀", Style::new().fg(CAT_BODY)),
            Span::styled("╶", Style::new().fg(CAT_BODY)),
            Span::raw(" "),
        ]),
    ]
}

fn running_sprite_1() -> Vec<Line<'static>> {
    vec![
        Line::from(vec![
            Span::raw(" "),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::raw(" "),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::raw("  "),
        ]),
        Line::from(vec![
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::styled("▀", Style::new().fg(CAT_EYE)),
            Span::styled("▀", Style::new().fg(CAT_NOSE)),
            Span::styled("▀", Style::new().fg(CAT_EYE)),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::styled("╶", Style::new().fg(CAT_BODY)),
        ]),
        Line::from(vec![
            Span::styled("╶", Style::new().fg(CAT_BODY)),
            Span::styled("╯", Style::new().fg(CAT_BODY)),
            Span::raw(" "),
            Span::styled("╰", Style::new().fg(CAT_BODY)),
            Span::raw("  "),
        ]),
    ]
}

fn running_sprite_2() -> Vec<Line<'static>> {
    vec![
        Line::from(vec![
            Span::raw(" "),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::raw(" "),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::raw("  "),
        ]),
        Line::from(vec![
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::styled("▀", Style::new().fg(CAT_EYE)),
            Span::styled("▀", Style::new().fg(CAT_NOSE)),
            Span::styled("▀", Style::new().fg(CAT_EYE)),
            Span::styled("▄", Style::new().fg(CAT_BODY)),
            Span::styled("╶", Style::new().fg(CAT_BODY)),
        ]),
        Line::from(vec![
            Span::raw(" "),
            Span::styled("╰", Style::new().fg(CAT_BODY)),
            Span::raw(" "),
            Span::styled("╯", Style::new().fg(CAT_BODY)),
            Span::raw("  "),
        ]),
    ]
}

/// Draw the cat sprite overlaying the top border of the bottom panel.
/// `bottom_area` is the Rect of the bottom panel (including its border).
/// The cat is positioned so its bottom row (feet) aligns with the border top row.
pub fn draw_cat(frame: &mut Frame, state: &AppState, bottom_area: Rect) {
    let sprite_lines = match state.cat_frame {
        1 => running_sprite_1(),
        2 => running_sprite_2(),
        _ => sitting_sprite(),
    };

    let sprite_height = sprite_lines.len() as u16;
    // Cat sits above the bottom panel border (not overlapping)
    let cat_y = bottom_area.y.saturating_sub(sprite_height);
    let cat_x = bottom_area.x + state.cat_x;

    for (i, line) in sprite_lines.iter().enumerate() {
        let y = cat_y + i as u16;
        // Skip if outside terminal bounds
        if y >= frame.area().height {
            continue;
        }
        let line_width: u16 = line.spans.iter().map(|s| s.content.width() as u16).sum();
        let available = frame.area().width.saturating_sub(cat_x);
        if available == 0 {
            continue;
        }
        let w = line_width.min(available);
        let area = Rect::new(cat_x, y, w, 1);
        frame.render_widget(line.clone(), area);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use ratatui::{Terminal, backend::TestBackend};

    #[test]
    fn sprite_frames_have_consistent_line_count() {
        let sitting = sitting_sprite();
        let run1 = running_sprite_1();
        let run2 = running_sprite_2();
        assert_eq!(sitting.len(), 3);
        assert_eq!(run1.len(), 3);
        assert_eq!(run2.len(), 3);
    }

    #[test]
    fn draw_cat_renders_without_panic() {
        let backend = TestBackend::new(60, 30);
        let mut terminal = Terminal::new(backend).unwrap();
        let mut state = AppState::new("%0".into());
        state.cat_x = 5;
        state.cat_frame = 0; // sitting

        terminal
            .draw(|frame| {
                let bottom_area = Rect::new(0, 20, 60, 10);
                draw_cat(frame, &state, bottom_area);
            })
            .unwrap();
    }

    #[test]
    fn draw_cat_running_frame() {
        let backend = TestBackend::new(60, 30);
        let mut terminal = Terminal::new(backend).unwrap();
        let mut state = AppState::new("%0".into());
        state.cat_x = 10;
        state.cat_frame = 1; // running frame 1

        terminal
            .draw(|frame| {
                let bottom_area = Rect::new(0, 20, 60, 10);
                draw_cat(frame, &state, bottom_area);
            })
            .unwrap();
    }
}
