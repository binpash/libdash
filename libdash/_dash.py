from ctypes import *


# nodes.h
NCMD      = 0;
NPIPE     = 1;
NREDIR    = 2;
NBACKGND  = 3;
NSUBSHELL = 4;
NAND      = 5;
NOR       = 6;
NSEMI     = 7;
NIF       = 8;
NWHILE    = 9;
NUNTIL    = 10;
NFOR      = 11;
NCASE     = 12;
NCLIST    = 13;
NDEFUN    = 14;
NARG      = 15;
NTO       = 16;
NCLOBBER  = 17;
NFROM     = 18;
NFROMTO   = 19;
NAPPEND   = 20;
NTOFD     = 21;
NFROMFD   = 22;
NHERE     = 23;
NXHERE    = 24;
NNOT      = 25;


# struct stackmark {
#     struct stack_block *stackp;
#     char *stacknxt;
#     size_t stacknleft;
# };
#
# The bindings use it only as an opaque buffer of this size; the fields
# carry their C names so that the layout check covers them too.
class stackmark (Structure):
    _fields_ = [("stackp",     c_void_p),
                ("stacknxt",   c_void_p),
                ("stacknleft", c_size_t)];

def init_stack (libdash):
    stack = create_string_buffer (sizeof (stackmark));

    libdash.setstackmark.argtypes = [c_void_p]; # Pretend we don't know the contents
    libdash.setstackmark.restypes = None;
    libdash.setstackmark (stack);

    return (stack);

def pop_stack (libdash, smark):
    # Inefficient, we should only initialize once

    libdash.popstackmark.argtypes = [c_void_p]; # Again, hide the contents
    libdash.popstackmark.restype = None;

    return (libdash.popstackmark (smark));


def dash_init (libdash):
    libdash.init.argtypes = [];
    libdash.init.restype = None;

    libdash.init ();


def initialize_dash_errno (libdash):
    libdash.initialize_dash_errno.argtypes = [];
    libdash.initialize_dash_errno.restype = None;

    libdash.initialize_dash_errno ();


def initialize (libdash):
    require_layout (libdash);
    initialize_dash_errno (libdash);
    dash_init (libdash);


def setinputtostdin (libdash):
    libdash.setinputfd.argtypes = [c_int, c_int];
    libdash.setinputfd.restype = None;

    libdash.setinputfd (0, 0);


# TODO: allow push parameter
def setinputfile (libdash, filename):
    libdash.setinputfile_safe.argtypes = [c_char_p, c_int];
    libdash.setinputfile_safe.restype = c_int;
    if (libdash.setinputfile_safe (filename.encode ('utf-8'), 0) < 0):
        raise OSError ("cannot open %s" % filename);


def setalias (libdash, name, value):
    libdash.setalias_safe.argtypes = [c_char_p, c_char_p];
    libdash.setalias_safe.restype = c_int;
    if (libdash.setalias_safe (name.encode ('utf-8'), value.encode ('utf-8')) != 0):
        raise ValueError ("invalid alias name: %r" % name);


def unalias (libdash, name):
    """Returns True if `name` was an alias."""
    libdash.unalias.argtypes = [c_char_p];
    libdash.unalias.restype = c_int;
    return (libdash.unalias (name.encode ('utf-8')) == 0);


def parsecmd_safe (libdash, interactive):
    libdash.parsecmd_safe.argtypes = [c_int];
    libdash.parsecmd_safe.restype = c_void_p;

    return (libdash.parsecmd_safe (int (interactive)));


# Forward declarations to break recursive dependencies
class union_node (Union):
    pass;

class nodelist (Structure):
    pass;


class ncmd (Structure):
    _fields_ = [("type",     c_int),
                ("linno",    c_int),
                ("assign",   POINTER (union_node)),
                ("args",     POINTER (union_node)),
                ("redirect", POINTER (union_node))];

class npipe (Structure):
    _fields_ = [("type",   c_int),
               ("backgnd", c_int),
               ("cmdlist", POINTER (nodelist))];

class nredir (Structure):
    _fields_ = [("type",     c_int),
                ("linno",    c_int),
                ("n",        POINTER (union_node)),
                ("redirect", POINTER (union_node))];

class nbinary (Structure):
    _fields_ = [("type", c_int),
                ("ch1",  POINTER (union_node)),
                ("ch2",  POINTER (union_node))];

class nif (Structure):
    _fields_ = [("type",     c_int),
                ("test",     POINTER (union_node)),
                ("ifpart",   POINTER (union_node)),
                ("elsepart", POINTER (union_node))];

class nfor (Structure):
    _fields_ = [("type",  c_int),
                ("linno", c_int),
                ("args",  POINTER (union_node)),
                ("body",  POINTER (union_node)),
                ("var",   c_char_p)];

class ncase (Structure):
    _fields_ = [("type",  c_int),
                ("linno", c_int),
                ("expr",  POINTER (union_node)),
                ("cases", POINTER (union_node))];

class nclist (Structure):
    _fields_ = [("type",    c_int),
                ("next",    POINTER (union_node)),
                ("pattern", POINTER (union_node)),
                ("body",    POINTER (union_node))];

class ndefun (Structure):
    _fields_ = [("type",  c_int),
                ("linno", c_int),
                ("text",  c_char_p),
                ("body",  POINTER (union_node))];

class narg (Structure):
    _fields_ = [("type",      c_int),
                ("next",      POINTER (union_node)),
                ("text",      c_char_p),
                ("backquote", POINTER (nodelist))];

class nfile (Structure):
    _fields_ = [("type",     c_int),
                ("next",     POINTER (union_node)),
                ("fd",       c_int),
                ("fname",    POINTER (union_node)),
                ("expfname", c_char_p)]

class ndup (Structure):
    _fields_ = [("type",  c_int),
                ("next",  POINTER (union_node)),
                ("fd",    c_int),
                ("dupfd", c_int),
                ("vname", POINTER (union_node))];

class nhere (Structure):
    _fields_ = [("type", c_int),
                ("next", POINTER (union_node)),
                ("fd",   c_int),
                ("doc",  POINTER (union_node))];

class nnot (Structure):
    _fields_ = [("type", c_int),
                ("com",  POINTER (union_node))];


nodelist._fields_ = [("next", POINTER (nodelist)),
                     ("n",    POINTER (union_node))];

union_node._fields_ = [("type",    c_int),
                       ("ncmd",    ncmd),
                       ("npipe",   npipe),
                       ("nredir",  nredir),
                       ("nbinary", nbinary),
                       ("nif",     nif),
                       ("nfor",    nfor),
                       ("ncase",   ncase),
                       ("nclist",  nclist),
                       ("ndefun",  ndefun),
                       ("narg",    narg),
                       ("nfile",   nfile),
                       ("ndup",    ndup),
                       ("nhere",   nhere),
                       ("nnot",    nnot)];


class strpush (Structure):
    pass;

# struct strpush {
#     struct strpush *prev;   /* preceding string on stack */
#     char *prevstring;
#     int prevnleft;
#     struct alias *ap;   /* if push was associated with an alias */
#     char *string;       /* remember the string since it may change */
#
#     /* Delay freeing so we can stop nested aliases. */
#     struct strpush *spfree;
#
#     /* Number of outstanding calls to pungetc. */
#     int unget;
# };
strpush._fields_ = [("prev", POINTER (strpush)),
                    ("prevstring", c_char_p),
                    ("prevnleft", c_int),
                    ("ap", c_void_p),
                    ("string", c_char_p),
                    ("spfree", POINTER (strpush)),
                    ("unget", c_int)];

class parsefile (Structure):
    pass;

# struct parsefile {
#     struct parsefile *prev; /* preceding file on stack */
#     int linno;      /* current line */
#     int fd;         /* file descriptor (or -1 if string) */
#     int nleft;      /* number of chars left in this line */
#     int eof;        /* do not read again once we hit EOF */
#     char *nextc;        /* next char in buffer */
#     char *buf;      /* input buffer */
#     struct strpush *strpush; /* for pushing strings at this level */
#     struct strpush basestrpush; /* so pushing one is fast */
#
#     /* Delay freeing so we can stop nested aliases. */
#     struct strpush *spfree;
#
# #ifndef SMALL
#     int lleft;      /* number of chars left in this buffer */
# #endif
#
#     /* Number of outstanding calls to pungetc. */
#     int unget;
# };
#
# No lleft: configure.ac defines SMALL unless dash is built --with-libedit.
parsefile._fields_ = [("prev",        POINTER (parsefile)),
                      ("linno",       c_int),
                      ("fd",          c_int),
                      ("nleft",       c_int),
                      ("eof",         c_int),
                      ("nextc",       POINTER (c_char)), # NOT c_char_p!
                      ("buf",         c_char_p),
                      ("strpush",     POINTER (strpush)),
                      ("basestrpush", strpush),
                      ("spfree",      POINTER (strpush)),
                      ("unget",       c_int)];


# Every struct above, by its C name. libdash.so's libdash_struct_layout
# (generated by src/mklayout from the same list in src/Makefile.am) holds
# their real sizes and field offsets; require_layout compares the two.
LAYOUT = [("struct stackmark",  stackmark),
          ("struct nodelist",   nodelist),
          ("union node",        union_node),
          ("struct ncmd",       ncmd),
          ("struct npipe",      npipe),
          ("struct nredir",     nredir),
          ("struct nbinary",    nbinary),
          ("struct nif",        nif),
          ("struct nfor",       nfor),
          ("struct ncase",      ncase),
          ("struct nclist",     nclist),
          ("struct ndefun",     ndefun),
          ("struct narg",       narg),
          ("struct nfile",      nfile),
          ("struct ndup",       ndup),
          ("struct nhere",      nhere),
          ("struct nnot",       nnot),
          ("struct strpush",    strpush),
          ("struct parsefile",  parsefile)];


class LibdashLayoutError (Exception):
    """The ctypes structs in libdash/_dash.py disagree with the ones
    libdash.so was built with, so reading the AST would read the wrong
    fields."""
    pass;


class _layout_row (Structure):
    _fields_ = [("type",  c_char_p),
                ("field", c_char_p),   # NULL: value is the sizeof type
                ("value", c_size_t)];


def library_layout (libdash):
    """libdash.so's layout table, as {C type: (sizeof, {field: offset})},
    with fields in declaration order."""
    first = _layout_row.in_dll (libdash, "libdash_struct_layout");
    rows = cast (addressof (first), POINTER (_layout_row));

    out = {};
    i = 0;
    while (rows [i].type is not None):
        row = rows [i];
        ctype = row.type.decode ();
        if (row.field is None):
            out [ctype] = (row.value, {});
        else:
            out [ctype][1][row.field.decode ()] = row.value;
        i += 1;

    return out;


def layout_problems (libdash, layout):
    """How `layout` (rows like LAYOUT's) disagrees with libdash.so's table,
    as a list of messages; empty if they agree."""
    c = library_layout (libdash);
    mine = dict (layout);
    problems = [];

    for ctype in c:
        if ctype not in mine:
            problems.append ("%s: in libdash.so, but has no ctypes mirror" % ctype);

    for (ctype, cls) in layout:
        if ctype not in c:
            problems.append ("%s: has a ctypes mirror, but is not in libdash.so" % ctype);
            continue;

        (size, offsets) = c [ctype];
        fields = [name for (name, _t) in cls._fields_];

        if (sizeof (cls) != size):
            problems.append ("%s: sizeof is %d in C, %d in ctypes"
                             % (ctype, size, sizeof (cls)));

        for (name, offset) in offsets.items ():
            if name not in fields:
                problems.append ("%s.%s: in C (offset %d), missing from ctypes"
                                 % (ctype, name, offset));
            elif (getattr (cls, name).offset != offset):
                problems.append ("%s.%s: offset is %d in C, %d in ctypes"
                                 % (ctype, name, offset, getattr (cls, name).offset));

        for name in fields:
            if name not in offsets:
                problems.append ("%s.%s: in ctypes, not in C" % (ctype, name));

    return problems;


_layout_checked = False;

def require_layout (libdash, force = False):
    """Raises LibdashLayoutError unless LAYOUT matches libdash.so. Checks
    once per process, unless `force`."""
    global _layout_checked;

    if (_layout_checked and not force):
        return;

    problems = layout_problems (libdash, LAYOUT);
    if problems:
        raise LibdashLayoutError (
            "libdash/_dash.py's ctypes structs disagree with libdash.so:\n  "
            + "\n  ".join (problems));

    _layout_checked = True;


# dash.ast
# let rec nodelist (n : nodelist structure ptr) : (node union ptr) list =
#   if nullptr n
#   then []
#   else (n @-> nodelist_n)::nodelist (n @-> nodelist_next)
def nodelist (nl):
    snek = [];

    # ctypes has different semantics for POINTER vs. c_void_p
    # See https://groups.google.com/g/nzpug/c/5CJxaWjuQro
    while (nl):
        snek.append (nl.contents.n);
        nl = nl.contents.next;

    return snek;


def caselist (n):
    cases = [];

    while (n):
        nclist = n.contents.nclist;

        assert (nclist.type == 13);

        cases.append ((nclist.pattern, nclist.body));

        n = nclist.next;

    return (cases);


def explode_rev (bytes):
    charlist = explode (bytes);
    charlist.reverse ();

    return (charlist);


def explode (bytes):
    s = bytes.decode ("charmap");

    charlist = [];

    for i in range (len (s)):
        charlist.append (ord (s [i]));

    return (charlist);


def implode_rev (l):
    s = implode (reversed (l));

    return (s);


def implode (l):
    s = "";

    for c in l:
        s = s + chr (c);

    return (s);
