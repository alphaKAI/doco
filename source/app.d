import std.algorithm,
       std.format,
       std.getopt,
       std.range,
       std.regex,
       std.stdio,
       std.conv,
       std.uni;
import termbox;


static immutable CASE_INSENTIVE_MATCH_SCORE = 20;
static immutable PARTIAL_MATCH_SCORE        = 10;


/**
  Key codes
*/
enum KeyAction {
  ENTER = 13,
  ESC   = 27,
  SPACE = 32,
  BACKSPACE   = 127,
  ARROW_DOWN  = 65516,
  ARROW_UP    = 65517
}

/**
  vertical offset of items in screen.
*/
enum y_offset = 1; // for query input

/**
  This struct holds environment as states
*/
struct Env {
  string[] inputs,   // holds input from stdin(recieved from pipe)
           filtered, // holds holl data of filtered inputs
           render_items; // holds a part of filtered to output
  string query; // holds query to filter
  long selected, // indicates a current selected item of render_items(relative position of filtered in screen)
       cursor;   // indicates a current selected item of filtered(absolute position of filtered)
  size_t offset; // indicates an offset for reinder_items(first position of render_items is filtered[offset + selected])

  bool matchByRegex; // Use regex for matching.
}

// holds Env
static Env E;

/**
  write an item to screen

  ulong x: horizontal position of screen where will be printed
  ulong y: vertical position of screen where will be printed
  string line: contents of line
  bool selected: whether this item is selected, if this variable is true, the line will be printed with highlight
*/
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

/**
  update query
*/
void updateQuery(bool init = false) {
  string query = {
    immutable prompt = "QUERY%s> %s";
    Appender!string query = appender!string;

    formattedWrite(query, prompt, E.matchByRegex ? "[regex]" : "[fuzzy]", E.query);

    return query.data;
  }();

  foreach (x; width.iota) {
    uint c;

    if (x < query.length) {
      c = cast(uint)query[x];
    } else {
      c = cast(uint)' ';
    }

    if (x == query.length) {
      setCell(x.to!int, 0, cast(uint)c, cast(ushort)Color.white, cast(ushort)Color.white);
    } else {
      setCell(x.to!int, 0, cast(uint)c, cast(ushort)Color.white, cast(ushort)Color.black);
    }
  }

  if (init) {
    if (E.matchByRegex) {
      E.filtered     = filterByRegex;
    } else {
      E.filtered     = filterByFuzzyMatcher;
    }
    E.render_items = E.filtered;
    E.selected = 0;
    E.cursor   = 0;
    E.offset   = 0;
  }
}


/**
  update screen
*/
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

/**
  Filtering the input by regex based matching.
*/
string[] filterByRegex() {
  /+
    If you intend to input ".*/" to match directory, this filter(program) interpret by character.
    That means this program will act to interpret incomplete regex pattern,
    as such a pattern is invalid then this program causes an exception if belows try-catch block doesn't exist.
  +/
  if (E.query.empty) {
    return E.inputs;
  }
  try {
    auto rgx = regex(E.query);
    return E.inputs.filter!(x => x.match(rgx)).array;
  } catch {
    return E.inputs;
  }
  assert(false);
}


/**
  Calculate a score of fuzzy matching by naive algorithm.

    TODO: more efficent, more clever.
*/
long fuzzyScore(string input, string query) {
  long score;

  auto upperInput = input.toUpper;
  auto upperQuery = query.toUpper;

  // step1: case-insentive match.
  if (upperInput == upperQuery) {
    score += CASE_INSENTIVE_MATCH_SCORE;
  }

  // step 2: partial match.
  if (upperInput.canFind(upperQuery)) {
    score += PARTIAL_MATCH_SCORE;
  }

  // step 3: levenshteinDistance.
  score -= levenshteinDistance(input, query);

  return score;
}


unittest {
  assert(fuzzyScore("aaa", "AaA") > fuzzyScore("aaa", "bbb"));
  assert(!(fuzzyScore("aaa", "AaA") < fuzzyScore("aaa", "bbb")));
}


/**
  Filtering the input by fuzzy matching.
*/
string[] filterByFuzzyMatcher() {
  if (E.query.empty) {
    return E.inputs;
  }
  auto arr = E.inputs.dup;
  arr.sort!((a, b) => fuzzyScore(a, E.query) > fuzzyScore(b, E.query));

  // FIXME: how many items should we returns?
  return arr;
}


version(unittest) {
    void main() { }
}
else
void main(string[] args) {
  bool help, matchByRegex;

  try {
    args.getopt(
      "h|help", &help,          // print help menu.
      "r|regex", &matchByRegex  // use regex match instead fuzzy match.
    );
  }
  catch (GetOptException) {
      help = true;
  }

  if (help) {
      writeln(`doco

USAGE:
  doco [OPTION] [ARG]..
OPTION:
 -h, --help: display this help menu and exit.
 -r, --regex: use regex match instead fuzzy match.
`);
    return;
  }

  auto ansi_color_codes_rgx = ctRegex!`(\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K])`;

  foreach (line; stdin.byLine) {
    E.inputs ~= line.idup.replaceAll(ansi_color_codes_rgx, "");
  }

  bool quit;
  bool selected;

  E.matchByRegex = matchByRegex;

  {
    init;
    clear;
    scope(exit) shutdown;

    updateQuery(true);

    while (!quit) {
      updateItems;

      Event kevent;
      kevent.type = EventType.key;
      pollEvent(&kevent);

      immutable key = kevent.key;

      switch (key) with (KeyAction) {
        case ESC:
          quit = true;
          break;
        case ENTER:
          selected = E.render_items.empty ? false : true;
          quit     = true;
          break;
        case BACKSPACE:
          if (!E.query.empty) {
            E.query = E.query[0..$-1];
            updateQuery(true);
          }
          break;
        case ARROW_UP:
          if (E.selected > -1) { E.selected--; }
          if (E.cursor > 0) { E.cursor--; }

          if (E.selected == -1) {
            E.selected++;

            if (E.offset > 0) {
              E.offset--;
              E.render_items = E.filtered[E.offset..$];
            }
          }
          break;
        case ARROW_DOWN:
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
          break;
        default:
          if ((kevent.ch != 0) || (key == 32 && kevent.ch == 0)) {
            E.query ~= kevent.ch;
            updateQuery(true);
          }
        break;
      }
    }
  }

  if (selected) {
    writeln(E.render_items[E.selected]);
  }
}
