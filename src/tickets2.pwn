/*
Ticket System Bot, entirely written in Pawn using Discord-Connector.
Thanks to:
    - maddinat0r for discord-connector
    - IS4 for PawnPlus plugin
    - open.mp development team, The - for making such a customizable and modular binary
*/

#define FILTERSCRIPT

#include <default>
#include <float>
#include <omp-database>
#include <string>
#define PP_SYNTAX_AWAIT
#include <PawnPlus>
#include <discord-connector>
#include <a_mysql>
#define MYSQL_ASYNC_DEFAULT_PARALLEL true
#include <pp-mysql>

native format(output[], len = sizeof (output), const format[], {Float, _}:...);
#include <strlib>


#include "../src/modules/database.p"
#include "../src/modules/guild.p"
#include "../src/modules/ticket.p"

forward OnFilterScriptInit();
forward OnFilterScriptExit();

main(){}

public OnFilterScriptInit(){
    globalGuildPool = pool_new();
    databaseInit();
    loadGuilds();
    return 1;
}

public OnFilterScriptExit(){
    saveGuilds();
    pool_delete_deep(globalGuildPool);
    databaseExit();
    return 1;
}
