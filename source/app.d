import std.stdio, std.range, std.conv, std.regex;
import termbox;

enum KeyAction {
  ENTER = 13,
  ESC   = 27,
  SPACE = 32,
  BACKSPACE   = 127,
  ARROW_DOWN  = 65516,
  ARROW_UP    = 65517
}

enum y_offset = 1; // for query

struct Env {
  string[] inputs;
  string[] render_items;
  string[] filtered;
  size_t query_offset;
  string query;
  long selected,
       cursor;
  size_t offset;
}

static Env E;

void print(ulong x, ulong y, string line, bool selected) {
  uint c;

  if (x < line.length) {
    c = cast(uint)line[x];
  } else {
    c = cast(uint)' ';
  }

  if (selected) {
    setCell(x.to!int, (y + y_offset).to!int, c, cast(ushort)Color.red, cast(ushort)Color.white);
  } else {
    setCell(x.to!int, (y + y_offset).to!int, c, cast(ushort)Color.white, cast(ushort)Color.black);
  }
}

void updateQuery(bool init = false) {
  immutable query_header = "QUERY> ";
  string print_query  = query_header ~  E.query;

  foreach (x; width.iota) {
    uint c;

    if (x < print_query.length) {
      c = cast(uint)print_query[x];
    } else {
      c = cast(uint)' ';
    }

    if (x == print_query.length) {
      setCell(x.to!int, 0, cast(uint)c, cast(ushort)Color.white, cast(ushort)Color.white);
    } else {
      setCell(x.to!int, 0, cast(uint)c, cast(ushort)Color.white, cast(ushort)Color.black);
    }
  }

  if (init) {
    E.filtered     = filter;
    E.render_items = E.filtered;
    E.selected = 0;
    E.cursor   = 0;
    E.offset   = 0;
  }
}

void updateItems() {
  clear;
  updateQuery;

  foreach (y, input; E.render_items) {
    foreach (x; width.iota) {
      print(x, y, input, y == E.selected);
    }
  }

  flush;
}

string[] filter() {
  string[] ret;

  /+
    If you intend to input ".*/" to match directory, this filter(program) interpret by character.
    That means this program will act to interpret incomplete regex pattern,
    as such a pattern is invalid then this program causes an exception if belows try-catch block doesn't exist.
  +/
  try {
    auto rgx = regex(E.query);

    if (E.query.empty) {
      ret = E.inputs;
    } else {
      foreach (elem; E.inputs) {
        if (elem.match(rgx)) {
          ret ~= elem;
        }
      }
    }
  } catch {
    ret = E.inputs;
  }

  return ret;
}

void main() {
  foreach (line; stdin.byLine) {
    E.inputs ~= line.idup;
  }

  init;
  clear;

  bool quit;
  bool selected;

  updateQuery(true);

  while (!quit) {
    updateItems;

    Event kevent;
    kevent.type = EventType.key;
    pollEvent(&kevent);

    immutable key = kevent.key;

    with (KeyAction) {
      if (key == ENTER) { selected = true; quit = true; }
      else if (key == ESC) { quit = true; }
      else if (key == BACKSPACE) {
        if (!E.query.empty) {
          E.query = E.query[0..$-1];
          updateQuery(true);
        }
      }
      else if (key == ARROW_UP)    {
        if (E.selected > -1) { E.selected--; }
        if (E.cursor > 0) { E.cursor--; }

        if (E.selected == -1) {
          E.selected++;

          if (E.offset > 0) {
            E.offset--;
            E.render_items = E.filtered[E.offset..$];
          }
        }
      }
      else if (key == ARROW_DOWN)  {
        if (E.cursor < E.render_items.length-1) { E.cursor++; }
        if ((E.render_items.length < height - 1) && (E.selected < E.render_items.length-1)) { E.selected++; }
        else if ((E.render_items.length > height - 1) && (E.selected < height-1)) { E.selected++; }

        if (E.selected == height - 1) {
          E.selected--;
          if (E.offset < E.filtered.length-1) {
            E.offset++;
            E.render_items = E.filtered[E.offset..$];
          }
        }
      }
      else {
        // Except special keys(Ex: TAB, DEL)
        if ((kevent.ch != 0) || (key == 32 && kevent.ch == 0)) {
          E.query ~= kevent.ch;
          updateQuery(true);
        }
      }
    }
  }

  shutdown;

  if (selected) {
    writeln(E.render_items[E.selected]);
  }
}
