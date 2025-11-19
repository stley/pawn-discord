/*
Ticket System Bot, entirely written in Pawn using Discord-Connector.
Thanks to:
    - maddinat0r for discord-connector
    - IS4 for PawnPlus plugin
    - open.mp development team, The - for making such a customizable and modular binary
*/

#include <pawn-discord>
#define PP_SYNTAX_AWAIT
#include <PawnPlus>
#include <a_mysql>
#define MYSQL_ASYNC_DEFAULT_PARALLEL true
#include <pp-mysql>
#include <strlib>
#pragma option -d3


#include "../src/modules/database.p"
#include "../src/modules/guild.p"
#include "../src/modules/ticket.p"


static saveTimer;

main(){}



public OnFilterScriptInit(){
    saveTimer = SetTimer("saveGuilds", 900000, true);
    globalGuildPool = pool_new();
    guildCommandsList = list_new();
    databaseInit();
    loadGuilds();
    loadTickets();
    return 1;
}

public OnFilterScriptExit(){
    KillTimer(saveTimer);
    pool_delete_deep(globalGuildPool);
    list_delete_deep(guildCommandsList);
    databaseExit();
    return 1;
}


#undef FILTERSCRIPT