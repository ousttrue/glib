const std = @import("std");

const VERSION = "2.83.2";
const Sample = struct {
    name: []const u8,
    files: []const []const u8,
};
const SAMPLES = [_]Sample{
    .{ .name = "glib", .files = &.{"src/main.c"} },
    .{ .name = "gobject", .files = &.{"src/example1.c"} },
    .{ .name = "gio", .files = &.{"src/hello-gio.c"} },
};
const FLAGS = [_][]const u8{
    "-DPCRE2_CODE_UNIT_WIDTH=8",
    "-DPCRE2_STATIC",
    "-Wno-macro-redefined",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libintl = buildIntl(b, target, optimize);
    const pcre2 = buildPcre(b, target, optimize);
    const libffi = buildFfi(b, target, optimize);
    const zlib = buildZlib(b, target, optimize);

    const glib = buildGlib(b, target, optimize);
    b.installArtifact(glib);
    glib.linkLibrary(libintl);
    glib.linkLibrary(pcre2);

    const gobject = buildGobject(b, target, optimize);
    b.installArtifact(gobject);
    gobject.linkLibrary(glib);
    gobject.linkLibrary(libintl);
    gobject.linkLibrary(libffi);
    gobject.linkLibrary(pcre2);

    const gmodule = buildGmodule(b, target, optimize);
    b.installArtifact(gmodule);
    gmodule.linkLibrary(glib);

    const gio = buildGio(b, target, optimize);
    b.installArtifact(gio);
    gio.linkLibrary(glib);
    gio.linkLibrary(gobject);
    gio.linkLibrary(libintl);
    gio.linkLibrary(gmodule);
    gio.linkLibrary(zlib);
    // gio.linkLibrary(gvdb);
    gio.addIncludePath(b.dependency("gvdb", .{}).path(""));

    const gvdb = buildGvdb(b, target, optimize);
    gvdb.linkLibrary(glib);
    gvdb.linkLibrary(gobject);
    gvdb.linkLibrary(gio);
    gvdb.linkLibrary(gmodule);

    for (SAMPLES) |sample| {
        const exe = b.addExecutable(.{
            .name = sample.name,
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFiles(.{
            .files = sample.files,
            .flags = &FLAGS,
        });
        exe.linkLibrary(glib);
        exe.linkLibrary(gobject);
        exe.linkLibrary(gio);
        exe.linkLibrary(gmodule);
        exe.linkLibrary(gvdb);
        exe.addIncludePath(glib.getEmittedIncludeTree().path(b, "glib"));
        exe.addIncludePath(gmodule.getEmittedIncludeTree().path(b, "gmodule"));

        const install = b.addInstallArtifact(exe, .{});
        const run = b.addRunArtifact(exe);
        run.step.dependOn(&install.step);
        b.step(b.fmt("run-{s}", .{sample.name}), b.fmt("run {s}", .{sample.name})).dependOn(&run.step);
    }
}

pub fn buildGmodule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "gmodule",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addCSourceFiles(.{
        .root = b.path("gmodule"),
        .files = &.{
            "gmodule.c",
        },
        .flags = &(.{
            // "-DGIO_COMPILATION",
        } ++ FLAGS),
    });
    lib.addIncludePath(b.path(""));
    // glib.h
    lib.addIncludePath(b.path("glib"));
    // config.h
    lib.addIncludePath(b.path("generated"));
    // gmoduleconf.h
    lib.addIncludePath(b.path("generated/gmodule"));

    const gmodule_visibility_h = blk: {
        const run = b.addSystemCommand(&.{"py"});
        run.addFileArg(b.path("tools/gen-visibility-macros.py"));
        run.addArg(VERSION);
        run.addArg("visibility-macros");
        run.addArg("GMODULE");
        break :blk run.addOutputFileArg("gmodule/gmodule-visibility.h");
    };
    lib.addIncludePath(gmodule_visibility_h.dirname().dirname());
    lib.installHeader(gmodule_visibility_h, "gmodule/gmodule-visibility.h");
    lib.installHeadersDirectory(b.path("gmodule"), "gmodule", .{});

    return lib;
}

pub fn buildGio(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "gio",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addCSourceFiles(.{
        .root = b.path("gio"),
        .files = &GIO_SRCS,
        .flags = &(.{
            "-DGIO_COMPILATION",
        } ++ FLAGS),
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "generated/gio/gioenumtypes.c",
            "generated/gio/gdbus-daemon-generated.c",
        },
        .flags = &(.{
            "-DGIO_COMPILATION",
        } ++ FLAGS),
    });
    lib.addIncludePath(b.path(""));
    lib.addIncludePath(b.path("gio"));
    // <glib-object.h>
    lib.addIncludePath(b.path("glib"));
    // <gmodule.h>
    lib.addIncludePath(b.path("gmodule"));
    // config.h
    lib.addIncludePath(b.path("generated"));
    lib.addIncludePath(b.path("generated/gio"));

    lib.installHeader(b.path("generated/gio/gioenumtypes.h"), "gio/gioenumtypes.h");
    lib.installHeadersDirectory(b.path("gio"), "gio", .{});

    const gio_visibility_h = blk: {
        const run = b.addSystemCommand(&.{"py"});
        run.addFileArg(b.path("tools/gen-visibility-macros.py"));
        run.addArg(VERSION);
        run.addArg("visibility-macros");
        run.addArg("GIO");
        break :blk run.addOutputFileArg("gio/gio-visibility.h");
    };
    lib.addIncludePath(gio_visibility_h.dirname().dirname());
    lib.installHeader(gio_visibility_h, "gio/gio-visibility.h");

    lib.linkSystemLibrary("Shlwapi");
    lib.linkSystemLibrary("Iphlpapi");
    lib.linkSystemLibrary("Dnsapi");
    return lib;
}

pub fn buildGobject(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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
        .flags = &(.{
            "-DGOBJECT_COMPILATION",
        } ++ FLAGS),
    });
    lib.addIncludePath(b.path(""));
    // <glib-object.h>
    lib.addIncludePath(b.path("glib"));
    // config.h
    lib.addIncludePath(b.path("generated"));
    // glibconfig.h
    lib.addIncludePath(b.path("generated/glib"));

    const gobject_visibility_h = blk: {
        const run = b.addSystemCommand(&.{"py"});
        run.addFileArg(b.path("tools/gen-visibility-macros.py"));
        run.addArg(VERSION);
        run.addArg("visibility-macros");
        run.addArg("GOBJECT");
        break :blk run.addOutputFileArg("gobject/gobject-visibility.h");
    };
    lib.addIncludePath(gobject_visibility_h.dirname().dirname());
    lib.installHeader(gobject_visibility_h, "gobject/gobject-visibility.h");

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
    lib.installHeader(b.path("generated/gobject/glib-enumtypes.h"), "gobject/glib-enumtypes.h");

    // glib_enumtypes_c = custom_target('glib_enumtypes_c',
    //   output : 'glib-enumtypes.c',
    //   capture : true,
    //   input : glib_enumtypes_input_headers,
    //   depends : [glib_enumtypes_h],
    //   command : [python, glib_mkenums,
    //              '--template', files('glib-enumtypes.c.template'),
    //              '@INPUT@'])

    lib.installHeadersDirectory(b.path("gobject"), "gobject", .{});
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
        .flags = &(.{
            "-DGLIB_COMPILATION",
        } ++ FLAGS),
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

fn buildFfi(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const dep = b.dependency("libffi", .{});
    const lib = b.addStaticLibrary(.{
        .name = "intl",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "src/prep_cif.c",
            "src/types.c",
            "src/raw_api.c",
            "src/java_raw_api.c",
            "src/closures.c",
            "src/x86/ffiw64.c",
            "src/x86/win64.S",
        },
    });
    lib.addIncludePath(b.path("generated"));
    lib.addIncludePath(b.path("generated/libffi"));
    lib.addIncludePath(dep.path("include"));
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

    var table = b.addWriteFiles().addCopyFile(dep.path("src/pcre2_chartables.c.dist"), "pcre2_chartables.c");

    const flags = [_][]const u8{
        "-DHAVE_CONFIG_H",
        "-D_GNU_SOURCE",
    } ++ FLAGS;

    lib.addCSourceFiles(.{
        .root = table.dirname(),
        .files = &.{
            // ${PROJECT_BINARY_DIR}/pcre2_chartables.c
            "pcre2_chartables.c",
        },
        .flags = &flags,
    });
    lib.addIncludePath(dep.path("src"));

    lib.addCSourceFiles(.{
        .root = dep.path("src"),
        .files = &.{
            "pcre2_auto_possess.c",
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
        .flags = &flags,
    });
    return lib;
}

fn buildZlib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const dep = b.dependency("zlib", .{});
    const lib = b.addStaticLibrary(.{
        .name = "zlib",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addIncludePath(dep.path(""));
    lib.installHeader(dep.path("zconf.h"), "zconf.h");
    lib.installHeader(dep.path("zlib.h"), "zlib.h");
    lib.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "adler32.c",
            "compress.c",
            "crc32.c",
            "deflate.c",
            "gzclose.c",
            "gzlib.c",
            "gzread.c",
            "gzwrite.c",
            "inflate.c",
            "infback.c",
            "inftrees.c",
            "inffast.c",
            "trees.c",
            "uncompr.c",
            "zutil.c",
        },
    });
    return lib;
}

fn buildGvdb(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const dep = b.dependency("gvdb", .{});
    const lib = b.addStaticLibrary(.{
        .name = "gvdb",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addIncludePath(b.path(""));
    lib.addIncludePath(b.path("glib"));
    lib.addIncludePath(b.path("gmodule"));
    lib.addIncludePath(b.path("generated"));
    lib.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "gvdb/gvdb-builder.c",
            "gvdb/gvdb-reader.c",
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

const GIO_SRCS = [_][]const u8{
    "gappinfo.c",
    "gasynchelper.c",
    "gasyncinitable.c",
    "gasyncresult.c",
    "gbufferedinputstream.c",
    "gbufferedoutputstream.c",
    "gbytesicon.c",
    "gcancellable.c",
    "gcharsetconverter.c",
    "gcontenttype.c",
    "gcontextspecificgroup.c",
    "gconverter.c",
    "gconverterinputstream.c",
    "gconverteroutputstream.c",
    "gcredentials.c",
    "gdatagrambased.c",
    "gdatainputstream.c",
    "gdataoutputstream.c",
    "gdebugcontroller.c",
    "gdebugcontrollerdbus.c",
    "gdrive.c",
    "gdummyfile.c",
    "gdummyproxyresolver.c",
    "gdummytlsbackend.c",
    "gemblem.c",
    "gemblemedicon.c",
    "gfile.c",
    "gfileattribute.c",
    "gfileenumerator.c",
    "gfileicon.c",
    "gfileinfo.c",
    "gfileinputstream.c",
    "gfilemonitor.c",
    "gfilenamecompleter.c",
    "gfileoutputstream.c",
    "gfileiostream.c",
    "gfilterinputstream.c",
    "gfilteroutputstream.c",
    "gicon.c",
    "ginetaddress.c",
    "ginetaddressmask.c",
    "ginetsocketaddress.c",
    "ginitable.c",
    "ginputstream.c",
    "gioerror.c",
    "giomodule.c",
    "giomodule-priv.c",
    "gioscheduler.c",
    "giostream.c",
    "gloadableicon.c",
    "gmarshal-internal.c",
    "gmount.c",
    "gmemorymonitor.c",
    "gmemorymonitordbus.c",
    "gmemoryinputstream.c",
    "gmemoryoutputstream.c",
    "gmountoperation.c",
    "gnativesocketaddress.c",
    "gnativevolumemonitor.c",
    "gnetworkaddress.c",
    "gnetworking.c",
    "gnetworkmonitor.c",
    "gnetworkmonitorbase.c",
    "gnetworkservice.c",
    "goutputstream.c",
    "gpermission.c",
    "gpollableinputstream.c",
    "gpollableoutputstream.c",
    "gpollableutils.c",
    "gpollfilemonitor.c",
    "gpowerprofilemonitor.c",
    "gpowerprofilemonitordbus.c",
    "gproxy.c",
    "gproxyaddress.c",
    "gproxyaddressenumerator.c",
    "gproxyresolver.c",
    "gresolver.c",
    "gresource.c",
    "gresourcefile.c",
    "gseekable.c",
    "gsimpleasyncresult.c",
    "gsimpleiostream.c",
    "gsimplepermission.c",
    "gsimpleproxyresolver.c",
    "gsocket.c",
    "gsocketaddress.c",
    "gsocketaddressenumerator.c",
    "gsocketclient.c",
    "gsocketconnectable.c",
    "gsocketconnection.c",
    "gsocketcontrolmessage.c",
    "gsocketinputstream.c",
    "gsocketlistener.c",
    "gsocketoutputstream.c",
    "gsocketservice.c",
    "gsrvtarget.c",
    "gsubprocesslauncher.c",
    "gsubprocess.c",
    "gtask.c",
    "gtcpconnection.c",
    "gtcpwrapperconnection.c",
    "gthemedicon.c",
    "gthreadedsocketservice.c",
    "gthreadedresolver.c",
    "gthreadedresolver.h",
    "gtlsbackend.c",
    "gtlscertificate.c",
    "gtlsclientconnection.c",
    "gtlsconnection.c",
    "gtlsdatabase.c",
    "gtlsfiledatabase.c",
    "gtlsinteraction.c",
    "gtlspassword.c",
    "gtlsserverconnection.c",
    "gdtlsconnection.c",
    "gdtlsclientconnection.c",
    "gdtlsserverconnection.c",
    "gunionvolumemonitor.c",
    "gunixconnection.c",
    "gunixfdlist.c",
    "gunixcredentialsmessage.c",
    "gunixsocketaddress.c",
    "gvfs.c",
    "gvolume.c",
    "gvolumemonitor.c",
    "gzlibcompressor.c",
    "gzlibdecompressor.c",
    "glistmodel.c",
    "gliststore.c",

    "ghttpproxy.c",
    "glocalfile.c",
    "glocalfileenumerator.c",
    "glocalfileinfo.c",
    "glocalfileinputstream.c",
    "glocalfilemonitor.c",
    "glocalfileoutputstream.c",
    "glocalfileiostream.c",
    "glocalvfs.c",
    "gsocks4proxy.c",
    "gsocks4aproxy.c",
    "gsocks5proxy.c",
    "thumbnail-verify.c",

    "gcontenttype-win32.c",
    "gwin32appinfo.c",
    "gmemorymonitorwin32.c",
    "gregistrysettingsbackend.c",
    "gwin32registrykey.c",
    "gwin32mount.c",
    "gwin32volumemonitor.c",
    "gwin32inputstream.c",
    "gwin32outputstream.c",
    "gwin32file-sync-stream.c",
    "gwin32packageparser.c",
    "gwin32networkmonitor.c",
    "gwin32networkmonitor.h",
    "gwin32notificationbackend.c",
    "gwin32sid.c",
    "gwin32sid.h",

    "win32/gwin32fsmonitorutils.c",
    "win32/gwin32filemonitor.c",
    "win32/gwinhttpvfs.c",
    "win32/gwinhttpfile.c",
    "win32/gwinhttpfileinputstream.c",
    "win32/gwinhttpfileoutputstream.c",

    "gdelayedsettingsbackend.c",
    "gkeyfilesettingsbackend.c",
    "gmemorysettingsbackend.c",
    "gnullsettingsbackend.c",
    "gsettingsbackend.c",
    "gsettingsschema.c",
    "gsettings-mapping.c",
    "gsettings.c",

    "gapplication.c",
    "gapplicationcommandline.c",
    "gapplicationimpl-dbus.c",

    "gactiongroup.c",
    "gactionmap.c",
    "gsimpleactiongroup.c",
    "gremoteactiongroup.c",
    "gactiongroupexporter.c",
    "gdbusactiongroup.c",
    "gaction.c",
    "gpropertyaction.c",
    "gsimpleaction.c",

    "gmenumodel.c",
    "gmenu.c",
    "gmenuexporter.c",
    "gdbusmenumodel.c",
    "gnotification.c",
    "gnotificationbackend.c",

    "gdbusutils.c",
    "gdbusaddress.c",
    "gdbusauthobserver.c",
    "gdbusauth.c",
    "gdbusauthmechanism.c",
    "gdbusauthmechanismanon.c",
    "gdbusauthmechanismexternal.c",
    "gdbusauthmechanismsha1.c",
    "gdbuserror.c",
    "gdbusconnection.c",
    "gdbusmessage.c",
    "gdbusnameowning.c",
    "gdbusnamewatching.c",
    "gdbusproxy.c",
    "gdbusprivate.c",
    "gdbusintrospection.c",
    "gdbusmethodinvocation.c",
    "gdbusserver.c",
    "gdbusinterface.c",
    "gdbusinterfaceskeleton.c",
    "gdbusobject.c",
    "gdbusobjectskeleton.c",
    "gdbusobjectproxy.c",
    "gdbusobjectmanager.c",
    "gdbusobjectmanagerclient.c",
    "gdbusobjectmanagerserver.c",
    "gtestdbus.c",
    "gdbusdaemon.c",
};
