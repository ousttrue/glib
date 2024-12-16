#include <gio/gio.h>

gint
main (gint argc, gchar *argv[])
{
  GFile *gf;

  g_type_init ();
  gf = g_file_new_for_path ("sample.txt");
  return 0;
}
