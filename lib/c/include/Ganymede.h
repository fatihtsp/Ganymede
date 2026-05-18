/*=============================================================================
  Ganymede(TM) - Embeddable Native Scripting Engine
  C/C++ Single-Header Dynamic Loader

  Copyright (c) 2026-present tinyBigGAMES(TM) LLC
  All Rights Reserved.

  See LICENSE for license information
=============================================================================*/

/**
 * \file Ganymede.h
 *
 * \brief
 *   C/C++ single-header dynamic loader for Ganymede.dll. Provides complete
 *   access to the Ganymede embeddable scripting engine through opaque
 *   handles and flat function calls.
 *
 * \par String contract
 *   All strings crossing the DLL boundary are null-terminated UTF-8.
 *   Strings returned by the DLL are heap-allocated and the caller MUST
 *   free them with gny_free(). Strings passed to callbacks are
 *   stack-local and valid only during the callback invocation.
 *
 * \par Thread safety
 *   Each GnyEngine is independent. Multiple handles may be used from
 *   different threads. A single handle must not be accessed from
 *   multiple threads simultaneously.
 *
 * \par Usage
 *   In ONE .c/.cpp file, before including:
 *   \code{.c}
 *     #define GANYMEDE_IMPLEMENTATION
 *     #include "Ganymede.h"
 *   \endcode
 *   Then call gny_load("Ganymede.dll") at runtime.
 *
 * \par Quick example
 * \code{.c}
 *   #define GANYMEDE_IMPLEMENTATION
 *   #include "Ganymede.h"
 *   int main(void) {
 *       if (!gny_load("Ganymede.dll")) return 1;
 *       GnyEngine engine = gny_create();
 *       gny_load_from_string(engine, "module mem\n...", "demo.gny");
 *       if (gny_compile(engine)) {
 *           void* fn = gny_get_symbol(engine, "my_func");
 *       }
 *       gny_destroy(engine);
 *       gny_unload();
 *       return 0;
 *   }
 * \endcode
 *
 * \par Platform
 *   Windows 64-bit only.
 */

#ifndef GANYMEDE_H
#define GANYMEDE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------------------
   Constants
   --------------------------------------------------------------------------- */

/** \brief Value type ordinals matching TGnyValueType */
#define GNY_VT_VOID      0
#define GNY_VT_INT8      1
#define GNY_VT_INT16     2
#define GNY_VT_INT32     3
#define GNY_VT_INT64     4
#define GNY_VT_UINT8     5
#define GNY_VT_UINT16    6
#define GNY_VT_UINT32    7
#define GNY_VT_UINT64    8
#define GNY_VT_FLOAT32   9
#define GNY_VT_FLOAT64  10
#define GNY_VT_POINTER  11

/** \brief Optimization level ordinals matching TGnyOptLevel */
#define GNY_OPT_NONE     0
#define GNY_OPT_BASIC    1
#define GNY_OPT_FULL     2

/** \brief Linkage ordinals matching TGnyLinkage */
#define GNY_LINK_DEFAULT 0
#define GNY_LINK_C       1

/* ---------------------------------------------------------------------------
   Types
   --------------------------------------------------------------------------- */

/** \brief Boolean type (0 = false, non-zero = true). */
typedef int32_t GnyBool;

/** \brief Opaque handle to a Ganymede engine instance. */
typedef void* GnyEngine;

/** \brief Status callback. text is stack-local UTF-8, copy if needed. */
typedef void (*GnyStatusHandler)(const char* text, void* user_data);

/**
 * \brief Tagged value for crossing the DLL boundary.
 *
 * value_type is one of the GNY_VT_* constants. The union member
 * matching that type holds the actual value.
 */
typedef struct {
    int32_t value_type;
    union {
        int8_t   as_int8;
        int16_t  as_int16;
        int32_t  as_int32;
        int64_t  as_int64;
        uint8_t  as_uint8;
        uint16_t as_uint16;
        uint32_t as_uint32;
        uint64_t as_uint64;
        float    as_float32;
        double   as_float64;
        void*    as_pointer;
    };
} GnyValue;

/* ---------------------------------------------------------------------------
   Function pointer types
   --------------------------------------------------------------------------- */

/* Lifecycle */
typedef GnyEngine   (*pfn_gny_create)(void);
typedef void        (*pfn_gny_destroy)(GnyEngine engine);
typedef const char* (*pfn_gny_version)(void);
typedef void        (*pfn_gny_free)(const char* ptr);

/* Source Loading */
typedef void        (*pfn_gny_load_from_string)(GnyEngine engine,
                        const char* source, const char* filename);
typedef void        (*pfn_gny_load_from_file)(GnyEngine engine,
                        const char* filename);

/* Compilation */
typedef GnyBool     (*pfn_gny_compile)(GnyEngine engine);

/* Host Interop */
typedef void        (*pfn_gny_import_host)(GnyEngine engine,
                        const char* name, void* addr,
                        const int32_t* param_types, int32_t param_count,
                        int32_t return_type, int32_t linkage);

/* Invocation */
typedef GnyValue    (*pfn_gny_invoke)(GnyEngine engine, const char* name,
                        int32_t return_type);

/* Argument Building */
typedef void        (*pfn_gny_arg_clear)(GnyEngine engine);
typedef void        (*pfn_gny_arg_push_int8)(GnyEngine engine, int8_t value);
typedef void        (*pfn_gny_arg_push_int16)(GnyEngine engine, int16_t value);
typedef void        (*pfn_gny_arg_push_int32)(GnyEngine engine, int32_t value);
typedef void        (*pfn_gny_arg_push_int64)(GnyEngine engine, int64_t value);
typedef void        (*pfn_gny_arg_push_uint8)(GnyEngine engine, uint8_t value);
typedef void        (*pfn_gny_arg_push_uint16)(GnyEngine engine, uint16_t value);
typedef void        (*pfn_gny_arg_push_uint32)(GnyEngine engine, uint32_t value);
typedef void        (*pfn_gny_arg_push_uint64)(GnyEngine engine, uint64_t value);
typedef void        (*pfn_gny_arg_push_float32)(GnyEngine engine, float value);
typedef void        (*pfn_gny_arg_push_float64)(GnyEngine engine, double value);
typedef void        (*pfn_gny_arg_push_pointer)(GnyEngine engine, void* value);

/* Symbols */
typedef void*       (*pfn_gny_get_symbol)(GnyEngine engine,
                        const char* name);
typedef GnyBool     (*pfn_gny_has_symbol)(GnyEngine engine,
                        const char* name);
typedef char*       (*pfn_gny_get_symbol_names)(GnyEngine engine);

/* Configuration */
typedef void        (*pfn_gny_set_output_path)(GnyEngine engine,
                        const char* path);
typedef void        (*pfn_gny_add_lib_path)(GnyEngine engine,
                        const char* path);
typedef void        (*pfn_gny_set_optimization_level)(GnyEngine engine,
                        int32_t level);
typedef int32_t     (*pfn_gny_get_optimization_level)(GnyEngine engine);
typedef void        (*pfn_gny_set_dump_ir)(GnyEngine engine, GnyBool value);
typedef char*       (*pfn_gny_get_ssa_dump)(GnyEngine engine);

/* Conditional Compilation */
typedef void        (*pfn_gny_set_define)(GnyEngine engine,
                        const char* name, const char* value);
typedef void        (*pfn_gny_undefine)(GnyEngine engine,
                        const char* name);
typedef GnyBool     (*pfn_gny_is_defined)(GnyEngine engine,
                        const char* name);

/* Error Reporting */
typedef void        (*pfn_gny_print_errors)(GnyEngine engine);
typedef char*       (*pfn_gny_get_errors)(GnyEngine engine);
typedef GnyBool     (*pfn_gny_has_errors)(GnyEngine engine);

/* Status Callback */
typedef void        (*pfn_gny_set_status_callback)(GnyEngine engine,
                        GnyStatusHandler callback, void* user_data);

/* Debug */
typedef void        (*pfn_gny_report_leaks)(GnyEngine engine);

/* ---------------------------------------------------------------------------
   Global function pointers -- set by gny_load(), cleared by gny_unload()
   --------------------------------------------------------------------------- */

/* Lifecycle */
extern pfn_gny_create                  gny_create;
extern pfn_gny_destroy                 gny_destroy;
extern pfn_gny_version                 gny_version;
extern pfn_gny_free                    gny_free;

/* Source Loading */
extern pfn_gny_load_from_string        gny_load_from_string;
extern pfn_gny_load_from_file          gny_load_from_file;

/* Compilation */
extern pfn_gny_compile                 gny_compile;

/* Host Interop */
extern pfn_gny_import_host             gny_import_host;

/* Invocation */
extern pfn_gny_invoke                  gny_invoke;

/* Argument Building */
extern pfn_gny_arg_clear               gny_arg_clear;
extern pfn_gny_arg_push_int8           gny_arg_push_int8;
extern pfn_gny_arg_push_int16          gny_arg_push_int16;
extern pfn_gny_arg_push_int32          gny_arg_push_int32;
extern pfn_gny_arg_push_int64          gny_arg_push_int64;
extern pfn_gny_arg_push_uint8          gny_arg_push_uint8;
extern pfn_gny_arg_push_uint16         gny_arg_push_uint16;
extern pfn_gny_arg_push_uint32         gny_arg_push_uint32;
extern pfn_gny_arg_push_uint64         gny_arg_push_uint64;
extern pfn_gny_arg_push_float32        gny_arg_push_float32;
extern pfn_gny_arg_push_float64        gny_arg_push_float64;
extern pfn_gny_arg_push_pointer        gny_arg_push_pointer;

/* Symbols */
extern pfn_gny_get_symbol              gny_get_symbol;
extern pfn_gny_has_symbol              gny_has_symbol;
extern pfn_gny_get_symbol_names        gny_get_symbol_names;

/* Configuration */
extern pfn_gny_set_output_path         gny_set_output_path;
extern pfn_gny_add_lib_path            gny_add_lib_path;
extern pfn_gny_set_optimization_level  gny_set_optimization_level;
extern pfn_gny_get_optimization_level  gny_get_optimization_level;
extern pfn_gny_set_dump_ir             gny_set_dump_ir;
extern pfn_gny_get_ssa_dump            gny_get_ssa_dump;

/* Conditional Compilation */
extern pfn_gny_set_define              gny_set_define;
extern pfn_gny_undefine                gny_undefine;
extern pfn_gny_is_defined              gny_is_defined;

/* Error Reporting */
extern pfn_gny_print_errors            gny_print_errors;
extern pfn_gny_get_errors              gny_get_errors;
extern pfn_gny_has_errors              gny_has_errors;

/* Status Callback */
extern pfn_gny_set_status_callback     gny_set_status_callback;

/* Debug */
extern pfn_gny_report_leaks            gny_report_leaks;

/* ---------------------------------------------------------------------------
   Loader API
   --------------------------------------------------------------------------- */

/**
 * \brief Loads Ganymede.dll and resolves all function pointers.
 * \param dll_path  Path to Ganymede.dll.
 * \return 1 on success, 0 on failure.
 */
int gny_load(const char* dll_path);

/**
 * \brief Unloads the DLL and resets all function pointers to NULL.
 */
void gny_unload(void);

/**
 * \brief Checks whether the DLL is currently loaded.
 * \return 1 if loaded, 0 otherwise.
 */
int gny_is_loaded(void);

#ifdef __cplusplus
}
#endif

#endif /* GANYMEDE_H */

/* ===========================================================================
   IMPLEMENTATION
   ===========================================================================
   Define GANYMEDE_IMPLEMENTATION in exactly ONE .c or .cpp file before
   including this header to pull in the implementation.
   =========================================================================== */

#ifdef GANYMEDE_IMPLEMENTATION

#ifndef WIN32_LEAN_AND_MEAN
  #define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

/** \cond INTERNAL */

static HMODULE gny__dll_handle = 0;

/* Function pointer definitions */

/* Lifecycle */
pfn_gny_create                  gny_create                  = NULL;
pfn_gny_destroy                 gny_destroy                 = NULL;
pfn_gny_version                 gny_version                 = NULL;
pfn_gny_free                    gny_free                    = NULL;

/* Source Loading */
pfn_gny_load_from_string        gny_load_from_string        = NULL;
pfn_gny_load_from_file          gny_load_from_file          = NULL;

/* Compilation */
pfn_gny_compile                 gny_compile                 = NULL;

/* Host Interop */
pfn_gny_import_host             gny_import_host             = NULL;

/* Invocation */
pfn_gny_invoke                  gny_invoke                  = NULL;

/* Argument Building */
pfn_gny_arg_clear               gny_arg_clear               = NULL;
pfn_gny_arg_push_int8           gny_arg_push_int8           = NULL;
pfn_gny_arg_push_int16          gny_arg_push_int16          = NULL;
pfn_gny_arg_push_int32          gny_arg_push_int32          = NULL;
pfn_gny_arg_push_int64          gny_arg_push_int64          = NULL;
pfn_gny_arg_push_uint8          gny_arg_push_uint8          = NULL;
pfn_gny_arg_push_uint16         gny_arg_push_uint16         = NULL;
pfn_gny_arg_push_uint32         gny_arg_push_uint32         = NULL;
pfn_gny_arg_push_uint64         gny_arg_push_uint64         = NULL;
pfn_gny_arg_push_float32        gny_arg_push_float32        = NULL;
pfn_gny_arg_push_float64        gny_arg_push_float64        = NULL;
pfn_gny_arg_push_pointer        gny_arg_push_pointer        = NULL;

/* Symbols */
pfn_gny_get_symbol              gny_get_symbol              = NULL;
pfn_gny_has_symbol              gny_has_symbol              = NULL;
pfn_gny_get_symbol_names        gny_get_symbol_names        = NULL;

/* Configuration */
pfn_gny_set_output_path         gny_set_output_path         = NULL;
pfn_gny_add_lib_path            gny_add_lib_path            = NULL;
pfn_gny_set_optimization_level  gny_set_optimization_level  = NULL;
pfn_gny_get_optimization_level  gny_get_optimization_level  = NULL;
pfn_gny_set_dump_ir             gny_set_dump_ir             = NULL;
pfn_gny_get_ssa_dump            gny_get_ssa_dump            = NULL;

/* Conditional Compilation */
pfn_gny_set_define              gny_set_define              = NULL;
pfn_gny_undefine                gny_undefine                = NULL;
pfn_gny_is_defined              gny_is_defined              = NULL;

/* Error Reporting */
pfn_gny_print_errors            gny_print_errors            = NULL;
pfn_gny_get_errors              gny_get_errors              = NULL;
pfn_gny_has_errors              gny_has_errors              = NULL;

/* Status Callback */
pfn_gny_set_status_callback     gny_set_status_callback     = NULL;

/* Debug */
pfn_gny_report_leaks            gny_report_leaks            = NULL;

/* Helper macro: resolve one symbol or fail */
#define GNY__LOAD(var, type, name)                                          \
    do {                                                                    \
        var = (type)GetProcAddress(gny__dll_handle, name);                  \
        if (!var) {                                                         \
            MessageBoxA(NULL, name,                                         \
                "Ganymede: failed to load symbol",                          \
                MB_OK | MB_ICONERROR);                                      \
            gny_unload();                                                   \
            return 0;                                                       \
        }                                                                   \
    } while (0)

/* gny_load */
int gny_load(const char* dll_path)
{
    if (gny__dll_handle) return 1; /* already loaded */

    gny__dll_handle = LoadLibraryA(dll_path);
    if (!gny__dll_handle) {
        MessageBoxA(NULL, dll_path,
            "Ganymede: failed to load DLL",
            MB_OK | MB_ICONERROR);
        return 0;
    }

    /* Lifecycle */
    GNY__LOAD(gny_create,                  pfn_gny_create,                  "gny_create");
    GNY__LOAD(gny_destroy,                 pfn_gny_destroy,                 "gny_destroy");
    GNY__LOAD(gny_version,                 pfn_gny_version,                 "gny_version");
    GNY__LOAD(gny_free,                    pfn_gny_free,                    "gny_free");

    /* Source Loading */
    GNY__LOAD(gny_load_from_string,        pfn_gny_load_from_string,        "gny_load_from_string");
    GNY__LOAD(gny_load_from_file,          pfn_gny_load_from_file,          "gny_load_from_file");

    /* Compilation */
    GNY__LOAD(gny_compile,                 pfn_gny_compile,                 "gny_compile");

    /* Host Interop */
    GNY__LOAD(gny_import_host,             pfn_gny_import_host,             "gny_import_host");

    /* Invocation */
    GNY__LOAD(gny_invoke,                  pfn_gny_invoke,                  "gny_invoke");

    /* Argument Building */
    GNY__LOAD(gny_arg_clear,               pfn_gny_arg_clear,               "gny_arg_clear");
    GNY__LOAD(gny_arg_push_int8,           pfn_gny_arg_push_int8,           "gny_arg_push_int8");
    GNY__LOAD(gny_arg_push_int16,          pfn_gny_arg_push_int16,          "gny_arg_push_int16");
    GNY__LOAD(gny_arg_push_int32,          pfn_gny_arg_push_int32,          "gny_arg_push_int32");
    GNY__LOAD(gny_arg_push_int64,          pfn_gny_arg_push_int64,          "gny_arg_push_int64");
    GNY__LOAD(gny_arg_push_uint8,          pfn_gny_arg_push_uint8,          "gny_arg_push_uint8");
    GNY__LOAD(gny_arg_push_uint16,         pfn_gny_arg_push_uint16,         "gny_arg_push_uint16");
    GNY__LOAD(gny_arg_push_uint32,         pfn_gny_arg_push_uint32,         "gny_arg_push_uint32");
    GNY__LOAD(gny_arg_push_uint64,         pfn_gny_arg_push_uint64,         "gny_arg_push_uint64");
    GNY__LOAD(gny_arg_push_float32,        pfn_gny_arg_push_float32,        "gny_arg_push_float32");
    GNY__LOAD(gny_arg_push_float64,        pfn_gny_arg_push_float64,        "gny_arg_push_float64");
    GNY__LOAD(gny_arg_push_pointer,        pfn_gny_arg_push_pointer,        "gny_arg_push_pointer");

    /* Symbols */
    GNY__LOAD(gny_get_symbol,              pfn_gny_get_symbol,              "gny_get_symbol");
    GNY__LOAD(gny_has_symbol,              pfn_gny_has_symbol,              "gny_has_symbol");
    GNY__LOAD(gny_get_symbol_names,        pfn_gny_get_symbol_names,        "gny_get_symbol_names");

    /* Configuration */
    GNY__LOAD(gny_set_output_path,         pfn_gny_set_output_path,         "gny_set_output_path");
    GNY__LOAD(gny_add_lib_path,            pfn_gny_add_lib_path,            "gny_add_lib_path");
    GNY__LOAD(gny_set_optimization_level,  pfn_gny_set_optimization_level,  "gny_set_optimization_level");
    GNY__LOAD(gny_get_optimization_level,  pfn_gny_get_optimization_level,  "gny_get_optimization_level");
    GNY__LOAD(gny_set_dump_ir,             pfn_gny_set_dump_ir,             "gny_set_dump_ir");
    GNY__LOAD(gny_get_ssa_dump,            pfn_gny_get_ssa_dump,            "gny_get_ssa_dump");

    /* Conditional Compilation */
    GNY__LOAD(gny_set_define,              pfn_gny_set_define,              "gny_set_define");
    GNY__LOAD(gny_undefine,                pfn_gny_undefine,                "gny_undefine");
    GNY__LOAD(gny_is_defined,              pfn_gny_is_defined,              "gny_is_defined");

    /* Error Reporting */
    GNY__LOAD(gny_print_errors,            pfn_gny_print_errors,            "gny_print_errors");
    GNY__LOAD(gny_get_errors,              pfn_gny_get_errors,              "gny_get_errors");
    GNY__LOAD(gny_has_errors,              pfn_gny_has_errors,              "gny_has_errors");

    /* Status Callback */
    GNY__LOAD(gny_set_status_callback,     pfn_gny_set_status_callback,     "gny_set_status_callback");

    /* Debug */
    GNY__LOAD(gny_report_leaks,            pfn_gny_report_leaks,            "gny_report_leaks");

    return 1;
}

/* gny_unload */
void gny_unload(void)
{
    if (gny__dll_handle) {
        FreeLibrary(gny__dll_handle);
        gny__dll_handle = NULL;
    }

    gny_create                  = NULL;
    gny_destroy                 = NULL;
    gny_version                 = NULL;
    gny_free                    = NULL;
    gny_load_from_string        = NULL;
    gny_load_from_file          = NULL;
    gny_compile                 = NULL;
    gny_import_host             = NULL;
    gny_invoke                  = NULL;
    gny_arg_clear               = NULL;
    gny_arg_push_int8           = NULL;
    gny_arg_push_int16          = NULL;
    gny_arg_push_int32          = NULL;
    gny_arg_push_int64          = NULL;
    gny_arg_push_uint8          = NULL;
    gny_arg_push_uint16         = NULL;
    gny_arg_push_uint32         = NULL;
    gny_arg_push_uint64         = NULL;
    gny_arg_push_float32        = NULL;
    gny_arg_push_float64        = NULL;
    gny_arg_push_pointer        = NULL;
    gny_get_symbol              = NULL;
    gny_has_symbol              = NULL;
    gny_get_symbol_names        = NULL;
    gny_set_output_path         = NULL;
    gny_add_lib_path            = NULL;
    gny_set_optimization_level  = NULL;
    gny_get_optimization_level  = NULL;
    gny_set_dump_ir             = NULL;
    gny_get_ssa_dump            = NULL;
    gny_set_define              = NULL;
    gny_undefine                = NULL;
    gny_is_defined              = NULL;
    gny_print_errors            = NULL;
    gny_get_errors              = NULL;
    gny_has_errors              = NULL;
    gny_set_status_callback     = NULL;
    gny_report_leaks            = NULL;
}

/* gny_is_loaded */
int gny_is_loaded(void)
{
    return gny__dll_handle != NULL;
}

#undef GNY__LOAD

/** \endcond */

#ifdef __cplusplus
}
#endif

#endif /* GANYMEDE_IMPLEMENTATION */
