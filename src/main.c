/*
 * t9 executable entry point. All behavior lives in the .kry port
 * (src/app/app_main.kry, compiled to t9_main); this shim only keeps
 * the OS entry boundary in C.
 */
int t9_main(int argc, char **argv);

int main(int argc, char **argv)
{
    return t9_main(argc, argv);
}
