const std = @import("std");

const VERSION = "2.83.2";
const Sample = struct {
    name: []const u8,
    files: []const []const u8,
};
const SAMPLES = [_]Sample{
    .{ .name = "glib", .files = &.{"src/main.c"} },
    .{ .name = "gobject", .files = &.{"src/example1.c"} },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const glib = buildGlib(b, target, optimize);
    const gobject = buildGobject(b, target, optimize, glib);

    const intl = buildIntl(b, target, optimize);
    glib.linkLibrary(intl);

    const pcre2 = buildPcre(b, target, optimize);
    glib.linkLibrary(pcre2);

    for (SAMPLES) |sample| {
        const exe = b.addExecutable(.{
            .name = sample.name,
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFiles(.{
            .files = sample.files,
        });
        exe.linkLibrary(glib);
        exe.linkLibrary(gobject);

        const install = b.addInstallArtifact(exe, .{});
        const run = b.addRunArtifact(exe);
        run.step.dependOn(&install.step);
        b.step(b.fmt("run-{s}", .{sample.name}), b.fmt("run {s}", .{sample.name})).dependOn(&run.step);
    }
}

pub fn buildGobject(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    glib: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "gobject",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addCSourceFiles(.{
        .root = b.path("gobject"),
        .files = &GOBJECT_SRCS,
        .flags = &.{
            "-DGOBJECT_COMPILATION",
            "-Wno-macro-redefined",
        },
    });
    lib.addIncludePath(b.path(""));
    // config.h
    lib.addIncludePath(b.path("generated"));
    // glibconfig.h
    lib.addIncludePath(b.path("generated/glib"));
    lib.addIncludePath(b.path("glib"));

    const gobject_visibility_h = blk: {
        const run = b.addSystemCommand(&.{"py"});
        run.addFileArg(b.path("tools/gen-visibility-macros.py"));
        run.addArg(VERSION);
        run.addArg("visibility-macros");
        run.addArg("GOBJECT");
        break :blk run.addOutputFileArg("gobject/gobject-visibility.h");
    };
    lib.addIncludePath(gobject_visibility_h.dirname().dirname());
    lib.installHeader(gobject_visibility_h, "gobject-visibility.h");

    // glib_enumtypes_h = custom_target('glib_enumtypes_h',
    //   output : 'glib-enumtypes.h',
    //   capture : true,
    //   input : glib_enumtypes_input_headers,
    //   install : true,
    //   install_dir : join_paths(get_option('includedir'), 'glib-2.0/gobject'),
    //   install_tag: 'devel',
    //   command : [python, glib_mkenums,
    //              '--template', files('glib-enumtypes.h.template'),
    //              '@INPUT@'])

    // glib_enumtypes_c = custom_target('glib_enumtypes_c',
    //   output : 'glib-enumtypes.c',
    //   capture : true,
    //   input : glib_enumtypes_input_headers,
    //   depends : [glib_enumtypes_h],
    //   command : [python, glib_mkenums,
    //              '--template', files('glib-enumtypes.c.template'),
    //              '@INPUT@'])

    lib.linkLibrary(glib);

    return lib;
}

fn buildGlib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "glib",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addCSourceFiles(.{
        .root = b.path("glib"),
        .files = &GLIB_SRCS,
        .flags = &.{
            "-DGLIB_COMPILATION",
            "-Wno-macro-redefined",
        },
    });

    // config.h
    lib.addIncludePath(b.path("generated"));
    // glibconfig.h
    lib.addIncludePath(b.path("generated/glib"));
    lib.installHeader(b.path("generated/glib/glibconfig.h"), "glibconfig.h");
    lib.addIncludePath(b.path("generated/glib/gnulib"));

    const gversionmacros_h = blk: {
        const run = b.addSystemCommand(&.{"py"});
        run.addFileArg(b.path("tools/gen-visibility-macros.py"));
        run.addArg(VERSION);
        run.addArg("versions-macros");
        run.addFileArg(b.path("glib/gversionmacros.h.in"));
        break :blk run.addOutputFileArg("glib/gversionmacros.h");
    };
    lib.addIncludePath(gversionmacros_h.dirname().dirname());
    lib.installHeader(gversionmacros_h, "glib/gversionmacros.h");

    const glib_visibility_h = blk: {
        const run = b.addSystemCommand(&.{"py"});
        run.addFileArg(b.path("tools/gen-visibility-macros.py"));
        run.addArg(VERSION);
        run.addArg("visibility-macros");
        run.addArg("GLIB");
        break :blk run.addOutputFileArg("glib/glib-visibility.h");
    };
    lib.addIncludePath(glib_visibility_h.dirname().dirname());
    lib.installHeader(glib_visibility_h, "glib/glib-visibility.h");

    lib.installHeadersDirectory(b.path("glib"), "glib", .{});
    lib.addIncludePath(b.path(""));
    lib.addIncludePath(b.path("glib"));
    lib.addIncludePath(b.path("glib/gnulib"));

    return lib;
}

fn buildIntl(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const dep = b.dependency("libintl", .{});
    const lib = b.addStaticLibrary(.{
        .name = "intl",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "libintl.c",
        },
    });
    lib.installHeader(dep.path("libintl.h"), "libintl.h");

    lib.linkSystemLibrary("ole32");
    lib.linkSystemLibrary("Ws2_32");

    return lib;
}

fn buildPcre(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const dep = b.dependency("pcre2", .{});
    const lib = b.addStaticLibrary(.{
        .name = "pcre2",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const pcre2_h = b.addConfigHeader(
        .{
            .style = .{ .cmake = dep.path("src/pcre2.h.in") },
        },
        .{
            .PCRE2_MAJOR = 10,
            .PCRE2_MINOR = 45,
            .PCRE2_PRERELEASE = "-DEV",
            .PCRE2_DATE = "2024-06-09",
        },
    );
    lib.addConfigHeader(pcre2_h);
    lib.installHeader(pcre2_h.getOutput(), "pcre2.h");

    const config_h = b.addConfigHeader(
        .{
            .style = .{ .cmake = dep.path("config-cmake.h.in") },
            .include_path = "config.h",
        },
        .{
            .PCRE2_EXPORT = "",
            .PCRE2_LINK_SIZE = 2,
            .PCRE2_PARENS_NEST_LIMIT = 250,
            .PCRE2_HEAP_LIMIT = 20000000,
            .PCRE2_MAX_VARLOOKBEHIND = 255,
            .PCRE2_MATCH_LIMIT = 10000000,
            .PCRE2_MATCH_LIMIT_DEPTH = "MATCH_LIMIT",
            .PCRE2GREP_BUFSIZE = 20480,
            .PCRE2GREP_MAX_BUFSIZE = 1048576,
            .NEWLINE_DEFAULT = 2, //"LF",
        },
    );
    lib.addConfigHeader(config_h);

    lib.addCSourceFiles(.{
        .root = dep.path("src"),
        .files = &.{
            "pcre2_auto_possess.c",
            // ${PROJECT_BINARY_DIR}/pcre2_chartables.c
            "pcre2_chkdint.c",
            "pcre2_compile.c",
            "pcre2_compile_class.c",
            "pcre2_config.c",
            "pcre2_context.c",
            "pcre2_convert.c",
            "pcre2_dfa_match.c",
            "pcre2_error.c",
            "pcre2_extuni.c",
            "pcre2_find_bracket.c",
            "pcre2_jit_compile.c",
            "pcre2_maketables.c",
            "pcre2_match.c",
            "pcre2_match_data.c",
            "pcre2_newline.c",
            "pcre2_ord2utf.c",
            "pcre2_pattern_info.c",
            "pcre2_script_run.c",
            "pcre2_serialize.c",
            "pcre2_string_utils.c",
            "pcre2_study.c",
            "pcre2_substitute.c",
            "pcre2_substring.c",
            "pcre2_tables.c",
            "pcre2_ucd.c",
            "pcre2_valid_utf.c",
            "pcre2_xclass.c",
        },
        .flags = &.{
            "-DHAVE_CONFIG_H",
            "-DPCRE2_CODE_UNIT_WIDTH=32",
            "-DPCRE2_STATIC",
        },
    });
    return lib;
}
const GLIB_SRCS = [_][]const u8{
    "garcbox.c",
    "garray.c",
    "gasyncqueue.c",
    "gatomic.c",
    "gbacktrace.c",
    "gbase64.c",
    "gbitlock.c",
    "gbookmarkfile.c",
    "gbytes.c",
    "gcharset.c",
    "gchecksum.c",
    "gconvert.c",
    "gdataset.c",
    "gdate.c",
    "gdatetime.c",
    "gdatetime-private.c",
    "gdir.c",
    "genviron.c",
    "gerror.c",
    "gfileutils.c",
    "ggettext.c",
    "ghash.c",
    "ghmac.c",
    "ghook.c",
    "ghostutils.c",
    "giochannel.c",
    "gkeyfile.c",
    "glib-init.c",
    "glib-private.c",
    "glist.c",
    "gmain.c",
    "gmappedfile.c",
    "gmarkup.c",
    "gmem.c",
    "gmessages.c",
    "gnode.c",
    "goption.c",
    "gpathbuf.c",
    "gpattern.c",
    "gpoll.c",
    "gprimes.c",
    "gqsort.c",
    "gquark.c",
    "gqueue.c",
    "grand.c",
    "grcbox.c",
    "grefcount.c",
    "grefstring.c",
    "gregex.c",
    "gscanner.c",
    "gsequence.c",
    "gshell.c",
    "gslice.c",
    "gslist.c",
    "gspawn.c",
    "gstdio.c",
    "gstrfuncs.c",
    "gstring.c",
    "gstringchunk.c",
    "gstrvbuilder.c",
    "gtestutils.c",
    "gthread.c",
    "gthreadpool.c",
    "gtimer.c",
    "gtimezone.c",
    "gtrace.c",
    "gtranslit.c",
    "gtrashstack.c",
    "gtree.c",
    "guniprop.c",
    "gutf8.c",
    "gunibreak.c",
    "gunicollate.c",
    "gunidecomp.c",
    "guri.c",
    "gutils.c",
    "guuid.c",
    "gvariant.c",
    "gvariant-core.c",
    "gvariant-parser.c",
    "gvariant-serialiser.c",
    "gvarianttypeinfo.c",
    "gvarianttype.c",
    "gversion.c",
    "gwakeup.c",
    "gprintf.c",

    "gwin32.c",
    "gspawn-win32.c",
    "giowin32.c",

    "gnulib/asnprintf.c",
    "gnulib/printf.c",
    "gnulib/printf-args.c",
    "gnulib/printf-parse.c",
    "gnulib/printf-frexp.c",
    "gnulib/printf-frexpl.c",
    "gnulib/vasnprintf.c",
    "gnulib/xsize.c",
    "gnulib/isnan.c",
    "gnulib/isnand.c",
    "gnulib/isnanf.c",
    "gnulib/isnanl.c",

    "libcharset/localcharset.c",
};

const GOBJECT_SRCS = [_][]const u8{
    "gatomicarray.c",
    "gbinding.c",
    "gbindinggroup.c",
    "gboxed.c",
    "gclosure.c",
    "genums.c",
    "gmarshal.c",
    "gobject.c",
    "gparam.c",
    "gparamspecs.c",
    "gsignal.c",
    "gsignalgroup.c",
    "gsourceclosure.c",
    "gtype.c",
    "gtypemodule.c",
    "gtypeplugin.c",
    "gvalue.c",
    "gvaluearray.c",
    "gvaluetransform.c",
    "gvaluetypes.c",
};
