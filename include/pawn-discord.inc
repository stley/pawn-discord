#define FILTERSCRIPT
#include <default>
#include <float>
#include <string>
#include <discord-connector>

native format(output[], len = sizeof (output), const format[], {Float, _}:...);

native SetTimer(const functionName[], interval, bool:repeating);
native SetTimerEx(const functionName[], interval, bool:repeating, const specifiers[] = "", {Float, _}:...);
native bool:KillTimer(timerid);

forward OnFilterScriptInit();
forward OnFilterScriptExit();