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
  size_t query_offset;
  string query;
  ulong selected;
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
    setCell(x.to!int, (y + y_offset).to!int, c, cast(ushort)Color.black, cast(ushort)Color.white);
  }
}

void updateQuery() {
  string query_header = "QUERY> ";
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
}

void updateAll() {
  clear;
  updateQuery;

  foreach (y, input; filter) {
    foreach (x; width.iota) {
      print(x, y, input, y == E.selected);
    }
  }
  flush;
}

string[] filter() {
  string[] ret;

  if (E.query.empty) {
    ret = E.inputs;
  } else {
    foreach (elem; E.inputs) {
      if (elem.match(regex(E.query))) {
        ret ~= elem;
      }
    }
  }

  return ret;
}

void main() {
  foreach (line; stdin.byLine) {
    E.inputs ~= line.idup;
  }

  init;
  clear;

  size_t ct;
  bool quit;
  int[] keys;
  uint[] chs;
  bool selected;

  while (!quit) {
    updateAll;

    Event kevent;
    kevent.type = EventType.key;
    pollEvent(&kevent);

    auto key = kevent.key;
    with (KeyAction) {
      if (key == ENTER) { selected = true; quit = true; }
      else if (key == ESC) { quit = true; }
      else if (key == BACKSPACE) {
        if (!E.query.empty) {
          E.query = E.query[0..$-1];
        }
      }
      else if (key == ARROW_UP)    { if (E.selected > 0) E.selected--; }
      else if (key == ARROW_DOWN)  { if (E.selected < E.inputs.length) E.selected++; }
      else {
        // Except special keys(Ex: TAB, DEL)
        if ((kevent.ch != 0) || (key == 32 && kevent.ch == 0)) {
          E.query ~= kevent.ch;
        }
      }
    }
  }

  shutdown;

  if (selected) {
    writeln(E.inputs[E.selected]);
  }
}
