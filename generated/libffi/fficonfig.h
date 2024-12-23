/* fficonfig.h.in.  Generated from configure.ac by autoheader.  */

/* Define if building universal (internal helper macro) */
/* #undef AC_APPLE_UNIVERSAL_BUILD */

/* Define to the flags needed for the .section .eh_frame directive. */
#define EH_FRAME_FLAGS "aw"

/* Define this if you want extra debugging. */
/* #undef FFI_DEBUG */

/* Cannot use PROT_EXEC on this target, so, we revert to alternative means */
#define FFI_EXEC_TRAMPOLINE_TABLE 0

/* Define this if you want to enable pax emulated trampolines */
/* #undef FFI_MMAP_EXEC_EMUTRAMP_PAX */

/* Cannot use malloc on this target, so, we revert to alternative means */
/* #undef FFI_MMAP_EXEC_WRIT */

/* Define this if you do not want support for the raw API. */
/* #undef FFI_NO_RAW_API */

/* Define this if you do not want support for aggregate types. */
/* #undef FFI_NO_STRUCTS */

/* Define to 1 if you have `alloca', as a function or macro. */
/* #undef HAVE_ALLOCA */

/* Define to 1 if you have <alloca.h> and it should be used */
#define HAVE_ALLOCA_H 0

/* Define if your assembler supports .ascii. */
#define HAVE_AS_ASCII_PSEUDO_OP 1

/* Define if your assembler supports .cfi_* directives. */
/* #undef HAVE_AS_CFI_PSEUDO_OP */

/* Define if your assembler supports .register. */
/* #undef HAVE_AS_REGISTER_PSEUDO_OP */

/* Define if your assembler and linker support unaligned PC relative relocs.
   */
/* #undef HAVE_AS_SPARC_UA_PCREL */

/* Define if your assembler supports .string. */
#define HAVE_AS_STRING_PSEUDO_OP 1

/* Define if your assembler supports unwind section type. */
#define HAVE_AS_X86_64_UNWIND_SECTION_TYPE 1

/* Define if your assembler supports PC relative relocs. */
#define HAVE_AS_X86_PCREL 1

/* Define to 1 if you have the <dlfcn.h> header file. */
/* #undef HAVE_DLFCN_H */

/* Define if __attribute__((visibility("hidden"))) is supported. */
/* #undef HAVE_HIDDEN_VISIBILITY_ATTRIBUTE */

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H

/* Define if you have the long double type and it is bigger than a double */
#define HAVE_LONG_DOUBLE 1

/* Define if you support more than one size of the long double type */
#define HAVE_LONG_DOUBLE_VARIANT 0

/* Define to 1 if you have the `memcpy' function. */
#define HAVE_MEMCPY 1

/* Define to 1 if you have the <memory.h> header file. */
/* #undef HAVE_MEMORY_H */

/* Define to 1 if you have the `mkostemp' function. */
#undef HAVE_MKOSTEMP

/* Define to 1 if you have the `mmap' function. */
/* #undef HAVE_MMAP */

/* Define if mmap with MAP_ANON(YMOUS) works. */
/* #undef HAVE_MMAP_ANON */

/* Define if mmap of /dev/zero works. */
/* #undef HAVE_MMAP_DEV_ZERO */

/* Define if read-only mmap of a plain file works. */
/* #undef HAVE_MMAP_FILE */

/* Define if .eh_frame sections should be read-only. */
/* #undef HAVE_RO_EH_FRAME */

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H

/* Define to 1 if you have the <stdlib.h> header file. */
/* #undef HAVE_STDLIB_H */

/* Define to 1 if you have the <strings.h> header file. */
/* #undef HAVE_STRINGS_H */

/* Define to 1 if you have the <string.h> header file. */
/* #undef HAVE_STRING_H */

/* Define to 1 if you have the <sys/mman.h> header file. */
/* #undef HAVE_SYS_MMAN_H */

/* Define to 1 if you have the <sys/stat.h> header file. */
/* #undef HAVE_SYS_STAT_H */

/* Define to 1 if you have the <sys/types.h> header file. */
/* #undef HAVE_SYS_TYPES_H */

/* Define to 1 if you have the <unistd.h> header file. */
/* #undef HAVE_UNISTD_H */

/* The size of `double', as computed by sizeof. */
#define SIZEOF_DOUBLE 8

/* The size of `long double', as computed by sizeof. */
#define SIZEOF_LONG_DOUBLE 16

/* The size of `size_t', as computed by sizeof. */
#define SIZEOF_SIZE_T 8

/* Define if symbols are underscored. */
/* #undef SYMBOL_UNDERSCORE */

/* Define this if you are using Purify and want to suppress spurious messages.
   */
/* #undef USING_PURIFY */

/* Define WORDS_BIGENDIAN to 1 if your processor stores words with the most
   significant byte first (like Motorola and SPARC, unlike Intel). */
#if defined AC_APPLE_UNIVERSAL_BUILD
#if defined __BIG_ENDIAN__
#define WORDS_BIGENDIAN 1
#endif
#else
#ifndef WORDS_BIGENDIAN
/* #undef WORDS_BIGENDIAN */
#endif
#endif

/* Define to `unsigned int' if <sys/types.h> does not define. */
/* #undef size_t */

#ifdef HAVE_HIDDEN_VISIBILITY_ATTRIBUTE
#ifdef LIBFFI_ASM
#ifdef __APPLE__
#define FFI_HIDDEN(name) .private_extern name
#else
#define FFI_HIDDEN(name) .hidden name
#endif
#else
#define FFI_HIDDEN __attribute__ ((visibility ("hidden")))
#endif
#else
#ifdef LIBFFI_ASM
#define FFI_HIDDEN(name)
#else
#define FFI_HIDDEN
#endif
#endif
