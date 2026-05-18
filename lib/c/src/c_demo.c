/*=============================================================================
  Ganymede(TM) - Embeddable Native Scripting Engine

  Copyright (c) 2026-present tinyBigGAMES(TM) LLC
  All Rights Reserved.

  See LICENSE for license information

  c_demo.c
    Standalone C demo exercising the Ganymede DLL via dynamic loading.
    Compile with: compile.cmd [compiler]
=============================================================================*/

#define GANYMEDE_IMPLEMENTATION
#include "Ganymede.h"

#include <stdio.h>

/* ANSI color helpers */
#define CLR_RESET   "\033[0m"
#define CLR_BOLD    "\033[1m"
#define CLR_RED     "\033[31m"
#define CLR_GREEN   "\033[32m"
#define CLR_CYAN    "\033[36m"
#define CLR_MAGENTA "\033[35m"

static void header(const char* title)
{
    printf(CLR_CYAN CLR_BOLD "--- %s ---" CLR_RESET "\n", title);
}

static void status_handler(const char* text, void* user_data)
{
    (void)user_data;
    printf(CLR_MAGENTA "  %s" CLR_RESET "\n", text);
}

/* =========================================================================
   main
   ========================================================================= */

int main(void)
{
    GnyEngine engine;
    char* errors;
    char* names;

    if (!gny_load("..\\lib\\bin\\Ganymede.dll")) {
        printf(CLR_RED "Failed to load Ganymede.dll" CLR_RESET "\n");
        return 1;
    }

    printf(CLR_CYAN CLR_BOLD
           "Ganymede v%s - Embeddable Native Scripting Engine\n"
           "==================================================\n"
           CLR_RESET "\n", gny_version());

    engine = gny_create();
    gny_set_status_callback(engine, status_handler, NULL);

    /* --- Load & Compile ------------------------------------------------- */
    header("Load & Compile");
    gny_load_from_string(engine,
        "module mem c_demo;\n"
        "\n"
        "public routine add(a: int64; b: int64): int64;\n"
        "begin\n"
        "  return a + b;\n"
        "end;\n"
        "\n"
        "end.;"
        ,
        "c_demo.gny");

    if (gny_compile(engine)) {
        printf(CLR_GREEN "  Compilation succeeded!" CLR_RESET "\n\n");

        /* --- Symbol query ----------------------------------------------- */
        header("Symbols");
        names = gny_get_symbol_names(engine);
        printf("  Exported symbols: %s\n", names);
        gny_free(names);

        if (gny_has_symbol(engine, "add")) {
            printf("  'add' found at %p\n",
                gny_get_symbol(engine, "add"));
        }
        printf("\n");

        /* --- Invoke ----------------------------------------------------- */
        header("Invoke");
        {
            GnyValue result;

            gny_arg_push_int64(engine, 30);
            gny_arg_push_int64(engine, 12);
            result = gny_invoke(engine, "add", GNY_VT_INT64);
            printf("  add(30, 12) = %lld\n", (long long)result.as_int64);
        }
        printf("\n");
    } else {
        printf(CLR_RED "  Compilation failed." CLR_RESET "\n");
        gny_print_errors(engine);

        errors = gny_get_errors(engine);
        printf("  Errors JSON: %s\n", errors);
        gny_free(errors);
    }

    /* --- Cleanup -------------------------------------------------------- */
    gny_destroy(engine);
    gny_unload();

    printf(CLR_GREEN CLR_BOLD "Demo complete." CLR_RESET "\n");
    return 0;
}
